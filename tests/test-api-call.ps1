#!/usr/bin/env powershell
<#
.SYNOPSIS
    Test script to call WPMS D0080Dread_all webservice
.DESCRIPTION
    Gets authentication token and calls the D0080Dread_all endpoint
    with ARTC parameter containing JSON data.
#>

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

Write-Host "=== WPMS D0080Dread_all Webservice Test ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for credentials
$username = Read-Host "Enter username"
$passwordSecure = Read-Host "Enter password" -AsSecureString
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwordSecure))

Write-Host ""
Write-Host "Step 1: Retrieving token..." -ForegroundColor Yellow
$token = Get-AuthTokenFromWpms -Username $username -Password $password

if (-not $token) {
    Write-Host "[ERROR] Failed to retrieve token" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Token obtained" -ForegroundColor Green
Write-Host ""

# Prepare API call
# Use production WPMS host when requested
$server = "http://wpms.prodout.com"
$uri = "/Eve/api/WebService/D0080Dread_all"
$fullUri = "$server$uri"

# Query parameters
$queryParams = @{
    ARTC = '{"val1":"1303394"}'
}

Write-Host "Step 2: Calling API endpoint..." -ForegroundColor Yellow
Write-Host "Server: $server" -ForegroundColor Gray
Write-Host "URI: $uri" -ForegroundColor Gray
Write-Host "Webservice: D0080Dread_all" -ForegroundColor Gray
Write-Host "Parameters: ARTC=$($queryParams['ARTC'])" -ForegroundColor Gray
Write-Host ""
Write-Host "Full URI: $fullUri" -ForegroundColor Cyan
Write-Host ""

# Make API call
$response = Invoke-RestApiRequest `
    -Method GET `
    -Uri $fullUri `
    -QueryParameters $queryParams `
    -BearerToken $token `
    -ShowCurl

# Display results
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
