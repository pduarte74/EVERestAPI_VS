#!/usr/bin/env powershell
<#
.SYNOPSIS
    Interactive test script for WPMS API calls
.DESCRIPTION
    Prompts for endpoint, parameter names and values, then calls the API
    with hardcoded credentials (pduarte/Kik02006!).
#>

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

Write-Host "=== Interactive WPMS API Test ===" -ForegroundColor Cyan
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

# Get endpoint from user
Write-Host "Step 2: Configure API call" -ForegroundColor Yellow
$endpoint = Read-Host "Enter endpoint (e.g., /Eve/api/WebService/D0080Dread_all)"

# Build full URI
$server = "http://wpms.prodout.com"
$fullUri = "$server$endpoint"

# Get parameters
Write-Host ""
Write-Host "Parameters (leave parameter name empty to finish):" -ForegroundColor Gray
$queryParams = @{}
$paramCount = 1

while ($true) {
    Write-Host ""
    $paramName = Read-Host "Parameter $paramCount name (or press Enter to skip)"
    
    if ([string]::IsNullOrWhiteSpace($paramName)) {
        break
    }
    
    $paramValue = Read-Host "Parameter $paramCount value"
    $queryParams[$paramName] = $paramValue
    $paramCount++
}

Write-Host ""
Write-Host "Step 3: Calling API endpoint..." -ForegroundColor Yellow
Write-Host "Server: $server" -ForegroundColor Gray
Write-Host "Endpoint: $endpoint" -ForegroundColor Gray

if ($queryParams.Count -gt 0) {
    Write-Host "Parameters:" -ForegroundColor Gray
    foreach ($key in $queryParams.Keys) {
        Write-Host "  $key = $($queryParams[$key])" -ForegroundColor Gray
    }
} else {
    Write-Host "Parameters: (none)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Full URI: $fullUri" -ForegroundColor Cyan
Write-Host ""

# Make API call
if ($queryParams.Count -gt 0) {
    $response = Invoke-RestApiRequest `
        -Method GET `
        -Uri $fullUri `
        -QueryParameters $queryParams `
        -BearerToken $token `
        -ShowCurl
} else {
    $response = Invoke-RestApiRequest `
        -Method GET `
        -Uri $fullUri `
        -BearerToken $token `
        -ShowCurl
}

Write-Host ""
Write-Host "Step 4: Response" -ForegroundColor Yellow
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
