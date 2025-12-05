#!/usr/bin/env powershell
<#
.SYNOPSIS
    Creates an encrypted password file for WPMS API authentication
.DESCRIPTION
    This script prompts for a password and encrypts it using Windows Data Protection API (DPAPI).
    The encrypted password can only be decrypted by the same user account on the same machine.
.PARAMETER SecurePasswordFile
    Path to the secure password file (default: secure-password.txt)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SecurePasswordFile = "$PSScriptRoot\secure-password.txt"
)

Write-Host "=== WPMS API Secure Password Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create an encrypted password file that can only be read by your Windows account." -ForegroundColor Yellow
Write-Host ""

# Prompt for password
$securePassword = Read-Host "Enter password" -AsSecureString

# Convert to encrypted string
$encryptedPassword = $securePassword | ConvertFrom-SecureString

# Save to file
try {
    $encryptedPassword | Out-File -FilePath $SecurePasswordFile -Force
    Write-Host ""
    Write-Host "SUCCESS: Password encrypted and saved to:" -ForegroundColor Green
    Write-Host "  $SecurePasswordFile" -ForegroundColor White
    Write-Host ""
    Write-Host "NOTE: This file can only be decrypted by the account '$env:USERDOMAIN\$env:USERNAME' on this machine." -ForegroundColor Yellow
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to save password file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
