# Single Boot JAR runtime (D-108). Build context = repo root (aggregator + backend + harness).
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY .mvn .mvn
COPY mvnw mvnw
COPY mvnw.cmd mvnw.cmd
COPY pom.xml pom.xml
COPY harness harness
COPY backend backend
RUN chmod +x mvnw \
  && ./mvnw -pl backend -am -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
# curl for compose.prod healthcheck against /actuator/health
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/backend/target/nomad-games-backend-0.1.0-SNAPSHOT.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
