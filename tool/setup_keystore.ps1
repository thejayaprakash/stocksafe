<#
.SYNOPSIS
    Automates keystore creation and configuration for StockSafe production release builds.
.DESCRIPTION
    1. Creates an upload keystore outside the repository (C:\keys\stocksafe-upload.p12).
    2. Generates android/key.properties with proper forward slashes.
    3. Generates a secure 256-bit random offline voucher secret (C:\keys\stocksafe-voucher-secret.txt).
    4. Outputs base64 encoded keystore & secrets for GitHub Actions CI.
    5. Optionally triggers .\tool\build_release.ps1 immediately.
#>

[CmdletBinding()]
param(
    [string]$KeystoreDir = 'C:\keys',
    [string]$KeystoreName = 'stocksafe-upload.p12',
    [string]$Alias = 'stocksafe',
    [string]$Password,
    [string]$OrgName = 'StockSafe',
    [switch]$BuildNow
)

$ErrorActionPreference = 'Stop'

Write-Host "=== StockSafe Production Release Setup ===" -ForegroundColor Cyan
Write-Host ""

# 1. Ensure KeystoreDir exists
if (-not (Test-Path $KeystoreDir)) {
    New-Item -ItemType Directory -Path $KeystoreDir -Force | Out-Null
    Write-Host "Created directory: $KeystoreDir" -ForegroundColor Green
}

$keystorePath = Join-Path $KeystoreDir $KeystoreName
$secretFilePath = Join-Path $KeystoreDir 'stocksafe-voucher-secret.txt'

# 2. Keystore creation
if (Test-Path $keystorePath) {
    Write-Host "Existing keystore found at: $keystorePath" -ForegroundColor Yellow
} else {
    if (-not $Password) {
        $secPass = Read-Host -Prompt "Enter keystore password (used for both store and key)" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }

    if ([string]::IsNullOrWhiteSpace($Password)) {
        Write-Error "Password cannot be empty."
    }

    Write-Host "Generating PKCS12 keystore ($keystorePath)..." -ForegroundColor Cyan
    & keytool -genkeypair -v `
        -keystore $keystorePath `
        -storetype PKCS12 `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias $Alias `
        -storepass $Password `
        -keypass $Password `
        -dname "CN=$OrgName, OU=Mobile, O=$OrgName, L=Bangalore, ST=Karnataka, C=IN"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "keytool failed to generate keystore."
    }
    Write-Host "Keystore created successfully!" -ForegroundColor Green
}

# 3. Create or check Voucher Secret
if (-not (Test-Path $secretFilePath)) {
    Write-Host "Generating cryptographically secure voucher secret ($secretFilePath)..." -ForegroundColor Cyan
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $hexSecret = ([System.BitConverter]::ToString($bytes) -replace '-').ToLower()
    Set-Content -Path $secretFilePath -Value $hexSecret
    Write-Host "Generated voucher secret!" -ForegroundColor Green
} else {
    Write-Host "Existing voucher secret found at: $secretFilePath" -ForegroundColor Yellow
    $hexSecret = (Get-Content $secretFilePath | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } | Select-Object -First 1).Trim()
}

# 4. Create android/key.properties
$normalizedKeystorePath = $keystorePath.Replace('\', '/')
$keyPropsPath = 'android/key.properties'

if (-not (Test-Path $keyPropsPath)) {
    if (-not $Password) {
        $secPass = Read-Host -Prompt "Enter keystore password to configure android/key.properties" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }

    $propsContent = @"
storeFile=$normalizedKeystorePath
storePassword=$Password
keyAlias=$Alias
keyPassword=$Password
"@
    Set-Content -Path $keyPropsPath -Value $propsContent
    Write-Host "Created $keyPropsPath (excluded from git by android/.gitignore)" -ForegroundColor Green
} else {
    Write-Host "Existing $keyPropsPath detected." -ForegroundColor Yellow
}

# 5. Output GitHub Actions CI Secrets configuration
$keystoreBytes = [System.IO.File]::ReadAllBytes($keystorePath)
$keystoreBase64 = [System.Convert]::ToBase64String($keystoreBytes)

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " GITHUB ACTIONS CI SECRETS (For Automated Cloud Builds)   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "To enable automated production-ready builds on GitHub CI,"
Write-Host "add these secrets under: GitHub Repo -> Settings -> Secrets and variables -> Actions"
Write-Host ""
Write-Host "1. ANDROID_KEYSTORE_BASE64 :" -ForegroundColor Cyan
Write-Host "   (Base64 encoded string of $keystorePath - length: $($keystoreBase64.Length) chars)"
Write-Host "2. KEYSTORE_PASSWORD       : [Your Keystore Password]" -ForegroundColor Cyan
Write-Host "3. KEY_ALIAS               : $Alias" -ForegroundColor Cyan
Write-Host "4. KEY_PASSWORD            : [Your Keystore Password]" -ForegroundColor Cyan
Write-Host "5. STOCKSAFE_VOUCHER_SECRET: $hexSecret" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""

if ($BuildNow) {
    Write-Host "Triggering local release build now..." -ForegroundColor Cyan
    & .\tool\build_release.ps1 -SecretFile $secretFilePath
} else {
    Write-Host "To build a production release locally now, run:" -ForegroundColor Yellow
    Write-Host "  .\tool\build_release.ps1" -ForegroundColor White
}
