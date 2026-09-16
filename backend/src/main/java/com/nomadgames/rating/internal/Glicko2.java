package com.nomadgames.rating.internal;

/**
 * Vendored Glicko-2 (D-104 / STACK). One Ranked settle = one rating period with m=1 opponent.
 * Defaults: r=1500, RD=350, σ=0.06, τ=0.5. No Maven Glicko JAR.
 */
public final class Glicko2 {

    public static final double DEFAULT_R = 1500.0;
    public static final double DEFAULT_RD = 350.0;
    public static final double DEFAULT_VOLATILITY = 0.06;
    public static final double TAU = 0.5;
    public static final double SCALE = 173.7178;

    private static final double CONVERGENCE_TOLERANCE = 1.0e-6;
    private static final int ITERATION_MAX = 100;

    private Glicko2() {}

    public record Rating(double r, double rd, double sigma) {
        public Rating {
            if (rd <= 0 || sigma <= 0) {
                throw new IllegalArgumentException("rd/sigma");
            }
        }

        public static Rating unrated() {
            return new Rating(DEFAULT_R, DEFAULT_RD, DEFAULT_VOLATILITY);
        }
    }

    /**
     * @param score 1.0 win, 0.5 draw, 0.0 loss
     */
    public static Rating update(Rating player, Rating opponent, double score) {
        if (player == null || opponent == null) {
            throw new IllegalArgumentException("rating");
        }
        if (score != 0.0 && score != 0.5 && score != 1.0) {
            throw new IllegalArgumentException("score");
        }

        double mu = (player.r() - DEFAULT_R) / SCALE;
        double phi = player.rd() / SCALE;
        double sigma = player.sigma();
        double muJ = (opponent.r() - DEFAULT_R) / SCALE;
        double phiJ = opponent.rd() / SCALE;

        double g = g(phiJ);
        double e = e(mu, muJ, phiJ);
        double v = 1.0 / (g * g * e * (1.0 - e));
        double delta = v * g * (score - e);

        double newSigma = newVolatility(sigma, phi, v, delta);
        double phiStar = Math.sqrt(phi * phi + newSigma * newSigma);
        double phiPrime = 1.0 / Math.sqrt(1.0 / (phiStar * phiStar) + 1.0 / v);
        double muPrime = mu + phiPrime * phiPrime * g * (score - e);

        return new Rating(DEFAULT_R + SCALE * muPrime, SCALE * phiPrime, newSigma);
    }

    private static double g(double phi) {
        return 1.0 / Math.sqrt(1.0 + 3.0 * phi * phi / (Math.PI * Math.PI));
    }

    private static double e(double mu, double muJ, double phiJ) {
        return 1.0 / (1.0 + Math.exp(-g(phiJ) * (mu - muJ)));
    }

    private static double newVolatility(double sigma, double phi, double v, double delta) {
        double a = Math.log(sigma * sigma);
        double tau = TAU;
        double deltaSq = delta * delta;
        double phiSq = phi * phi;

        double A = a;
        double B;
        if (deltaSq > phiSq + v) {
            B = Math.log(deltaSq - phiSq - v);
        } else {
            double k = 1;
            B = a - k * Math.abs(tau);
            while (f(B, deltaSq, phiSq, v, a, tau) < 0) {
                k++;
                B = a - k * Math.abs(tau);
            }
        }

        double fA = f(A, deltaSq, phiSq, v, a, tau);
        double fB = f(B, deltaSq, phiSq, v, a, tau);
        int iterations = 0;
        while (Math.abs(B - A) > CONVERGENCE_TOLERANCE && iterations < ITERATION_MAX) {
            iterations++;
            double C = A + (A - B) * fA / (fB - fA);
            double fC = f(C, deltaSq, phiSq, v, a, tau);
            if (fC * fB <= 0) {
                A = B;
                fA = fB;
            } else {
                fA = fA / 2.0;
            }
            B = C;
            fB = fC;
        }
        return Math.exp(A / 2.0);
    }

    private static double f(double x, double deltaSq, double phiSq, double v, double a, double tau) {
        double ex = Math.exp(x);
        double num = ex * (deltaSq - phiSq - v - ex);
        double den = 2.0 * Math.pow(phiSq + v + ex, 2);
        return (num / den) - ((x - a) / (tau * tau));
    }
}
