# Shared toolchain for Flutter client and later Maven harness (01-06).
# Dot-source from nomad-game root:  . ./scripts/dev-env.ps1

$ErrorActionPreference = 'Stop'

if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $env:JAVA_HOME = Join-Path $env:USERPROFILE '.jdks\corretto-21.0.11'
}

if (-not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    throw "JAVA_HOME is not a JDK: $env:JAVA_HOME"
}

if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    $env:ANDROID_HOME = Join-Path $env:USERPROFILE 'Android\Sdk'
}

$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

$flutterRoot = Join-Path $env:USERPROFILE 'develop\flutter'
if (-not (Test-Path (Join-Path $flutterRoot 'bin\flutter.bat'))) {
    throw "Flutter SDK not found at $flutterRoot"
}

$prepend = @(
    (Join-Path $env:JAVA_HOME 'bin')
    (Join-Path $flutterRoot 'bin')
    (Join-Path $env:ANDROID_HOME 'platform-tools')
    (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin')
)

$parts = $env:PATH -split ';' | Where-Object { $_ -and ($prepend -notcontains $_) }
$env:PATH = ($prepend + $parts) -join ';'
