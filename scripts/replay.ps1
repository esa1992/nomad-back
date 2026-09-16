# Device / host documents path for throw_input.json and throw_resolved.json:
#   Android app documents: /data/data/com.nomadgames.client/app_flutter
#   The sandbox writes throw_input.json there after Hold Throw and watches
#   throw_resolved.json for Replay Throw (no REST).
#   Windows desktop proto dir: %USERPROFILE%\Documents\nomad-game-proto
#
# Usage (from nomad-game root, physical device via adb):
#   . ./scripts/dev-env.ps1
#   ./scripts/replay.ps1

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dev-env.ps1')

$root = Split-Path -Parent $PSScriptRoot
$deviceDocs = '/data/data/com.nomadgames.client/app_flutter'
$work = Join-Path $root '.tmp-replay'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$inputLocal = Join-Path $work 'throw_input.json'
$outputLocal = Join-Path $work 'throw_resolved.json'

adb pull "$deviceDocs/throw_input.json" $inputLocal
if ($LASTEXITCODE -ne 0) {
    throw "adb pull failed for $deviceDocs/throw_input.json"
}

$harness = Join-Path $root 'harness'
Push-Location $harness
try {
    & .\mvnw.cmd -q exec:java "-Dexec.args=$inputLocal $outputLocal"
    if ($LASTEXITCODE -ne 0) {
        throw "harness exec:java failed"
    }
}
finally {
    Pop-Location
}

adb push $outputLocal "$deviceDocs/throw_resolved.json"
if ($LASTEXITCODE -ne 0) {
    throw "adb push failed for $deviceDocs/throw_resolved.json"
}

Write-Host "Pushed throw_resolved.json to $deviceDocs"
