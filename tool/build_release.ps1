# Builds a release artifact with the voucher secret compiled in.
#
#   .\tool\build_release.ps1              # app bundle, for Play
#   .\tool\build_release.ps1 -Apk         # apk, for sideloading to testers
#
# WHY THIS EXISTS
#
# LicenseKey._secret is a String.fromEnvironment, which is resolved at COMPILE
# time. It is not read from android/key.properties, from the environment at
# runtime, or from anywhere else — only from --dart-define on the build
# command. A plain `flutter build appbundle --release` therefore produces a
# perfectly valid, signed, uploadable artifact in which every voucher is
# forgeable, because the fallback secret is a constant printed in the public
# source.
#
# Nothing about that build looks wrong. It is the quiet kind of mistake, so
# the correct build is made the easy one rather than the remembered one.

[CmdletBinding()]
param(
    [switch]$Apk,
    [string]$SecretFile = 'C:\keys\stocksafe-voucher-secret.txt',
    [string]$AdmobAppId = $env:ADMOB_APP_ID,
    [string]$RewardedAdUnitId = $env:ADMOB_REWARDED_AD_UNIT_ID
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SecretFile)) {
    Write-Error @"
No voucher secret at $SecretFile

That file holds the signing secret for offline vouchers. Without it this build
would ship the development placeholder, and anyone reading the source could
mint vouchers for your app.

Create it, or pass -SecretFile pointing at your copy. It must contain the same
value as the STOCKSAFE_VOUCHER_SECRET repository secret, or vouchers minted by
CI will not validate against what you ship.
"@
}

# First non-comment, non-empty line. The file carries explanatory comments.
$secret = Get-Content $SecretFile |
    Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
    Select-Object -First 1

if (-not $secret) { Write-Error "No secret value found in $SecretFile" }

if ($secret -eq 'stocksafe-dev-voucher-secret-do-not-ship') {
    Write-Error 'That file contains the development placeholder, not a real secret.'
}

if (-not (Test-Path "$env:JAVA_HOME\bin\javac.exe")) {
    $candidates = @(
        'C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot',
        (Get-Item 'C:\Program Files\Microsoft\jdk-17*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1),
        (Get-Item 'C:\Program Files\Java\jdk-17*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1)
    )
    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path "$cand\bin\javac.exe")) {
            $env:JAVA_HOME = $cand
            break
        }
    }
}

$flutterCmd = 'flutter'
if (-not (Get-Command 'flutter' -ErrorAction SilentlyContinue)) {
    if (Test-Path 'E:\tools\flutter\bin\flutter.bat') {
        $flutterCmd = 'E:\tools\flutter\bin\flutter.bat'
    } elseif (Test-Path 'C:\tools\flutter\bin\flutter.bat') {
        $flutterCmd = 'C:\tools\flutter\bin\flutter.bat'
    }
}

$target = if ($Apk) { 'apk' } else { 'appbundle' }

Write-Host "Building $target with the voucher secret from $SecretFile" -ForegroundColor Cyan
Write-Host ''

# The secret is passed as an argument, so it lands in this process's command
# line but not in your shell history — PowerShell records the script call, not
# the expansion.
$adArgs = @()
if ($RewardedAdUnitId) {
    $adArgs += "--dart-define=ADMOB_REWARDED_AD_UNIT_ID=$RewardedAdUnitId"
}
if ($AdmobAppId) {
    $adArgs += "-PadmobAppId=$AdmobAppId"
}

& $flutterCmd build $target --release "--dart-define=STOCKSAFE_VOUCHER_SECRET=$secret" --android-skip-build-dependency-validation @adArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Checking the launch gate against the same secret...' -ForegroundColor Cyan
& $flutterCmd test test/release_readiness_test.dart "--dart-define=STOCKSAFE_VOUCHER_SECRET=$secret"
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Warning 'The launch gate failed. Do not upload this artifact until it passes.'
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Done. Artifact generated successfully!' -ForegroundColor Green
$artifactPath = if ($Apk) { 'build\app\outputs\flutter-apk\app-release.apk' } else { 'build\app\outputs\bundle\release\app-release.aab' }
if (Test-Path $artifactPath) {
    Write-Host "Verifying signature on $artifactPath..." -ForegroundColor Cyan
    & jarsigner -verify -verbose:summary -certs $artifactPath
}
