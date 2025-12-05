#!/usr/bin/env powershell
<#
.SYNOPSIS
    Test script to get authentication token from WPMS
.DESCRIPTION
    Prompts user for username and password, then calls Get-AuthTokenFromWpms
    to retrieve a bearer token for API authentication.
#>

# Import the Get-AuthToken module
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"

Write-Host "=== WPMS Token Retrieval Test ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for credentials
$username = Read-Host "Enter username"
$passwordSecure = Read-Host "Enter password" -AsSecureString
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwordSecure))

Write-Host ""
Write-Host "Retrieving token..." -ForegroundColor Yellow

# Get the token
$token = Get-AuthTokenFromWpms -Username $username -Password $password

if ($token) {
    Write-Host "[OK] Token obtained successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Token:" -ForegroundColor Cyan
    Write-Host $token
    Write-Host ""
    Write-Host "Token length: $($token.Length) characters"
} else {
    Write-Host "[ERROR] Failed to retrieve token" -ForegroundColor Red
    exit 1
}
