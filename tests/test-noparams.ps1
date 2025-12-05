#!/usr/bin/env powershell
<#
.SYNOPSIS
    Test D0080Dread_all with hardcoded credentials, no parameters
.DESCRIPTION
    Uses hardcoded credentials (pduarte/Kik02006!) to get token
    and call D0080Dread_all endpoint without parameters.
#>

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

Write-Host "=== D0080Dread_all Test (No Parameters) ===" -ForegroundColor Cyan
Write-Host ""

# Hardcoded credentials
$username = "pduarte"
$password = "Kik02006!"

Write-Host "Step 1: Retrieving token..." -ForegroundColor Yellow
Write-Host "Username: $username" -ForegroundColor Gray

$token = Get-AuthTokenFromWpms -Username $username -Password $password

if (-not $token) {
    Write-Host "[ERROR] Failed to retrieve token" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Token obtained" -ForegroundColor Green
Write-Host ""

# Prepare API call
$server = "http://wpms.prodout.com"
$uri = "/Eve/api/WebService/D0080Dread_all"
$fullUri = "$server$uri"

Write-Host "Step 2: Calling API endpoint..." -ForegroundColor Yellow
Write-Host "Server: $server" -ForegroundColor Gray
Write-Host "URI: $uri" -ForegroundColor Gray
Write-Host "Webservice: D0080Dread_all" -ForegroundColor Gray
Write-Host "Parameters: (none)" -ForegroundColor Gray
Write-Host ""
Write-Host "Full URI: $fullUri" -ForegroundColor Cyan
Write-Host ""

# Make API call without parameters
$response = Invoke-RestApiRequest `
    -Method GET `
    -Uri $fullUri `
    -BearerToken $token `
    -ShowCurl

Write-Host ""
Write-Host "Step 3: Response" -ForegroundColor Yellow
Write-Host ""

if ($response.Success) {
    Write-Host "[OK] Request successful" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Cyan
    Write-Host ""
    
    if ($response.Content) {
        Write-Host "Response Content:" -ForegroundColor Cyan
        $response.Content | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        Write-Host "Raw Response:" -ForegroundColor Cyan
        Write-Host $response.RawContent
    }
} else {
    Write-Host "[ERROR] Request failed" -ForegroundColor Red
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Cyan
    Write-Host "Error: $($response.Error)" -ForegroundColor Red
    
    if ($response.RawContent) {
        Write-Host ""
        Write-Host "Raw Response:" -ForegroundColor Gray
        Write-Host $response.RawContent
    }
}
