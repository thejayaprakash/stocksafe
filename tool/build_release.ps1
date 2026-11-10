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

& flutter build $target --release "--dart-define=STOCKSAFE_VOUCHER_SECRET=$secret" @adArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Checking the launch gate against the same secret...' -ForegroundColor Cyan
& flutter test test/release_readiness_test.dart "--dart-define=STOCKSAFE_VOUCHER_SECRET=$secret"
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Warning 'The launch gate failed. Do not upload this artifact until it passes.'
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host 'Done. Verify the signing certificate before uploading:' -ForegroundColor Green
Write-Host '  jarsigner -verify -verbose:summary -certs build\app\outputs\bundle\release\app-release.aab'
Write-Host 'The DN must be yours, not CN=Android Debug.'
