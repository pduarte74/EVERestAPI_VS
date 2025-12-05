#!/usr/bin/env powershell
<#
.SYNOPSIS
    Automated WPMS API test from configuration file
.DESCRIPTION
    Reads configuration file with credentials, endpoints and parameters,
    then calls each configured API endpoint sequentially and writes results to CSV.
.PARAMETER ConfigFile
    Path to the configuration file (default: ..\config\api-config.psd1)
.PARAMETER OutputFile
    Path to the output CSV file (default: test-results-TIMESTAMP.csv)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "C:\Tmp\EVERestAPI_VS\config\api-config.psd1",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

Write-Host "=== Automated WPMS API Test ===" -ForegroundColor Cyan
Write-Host ""

# Load configuration
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Configuration file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Gray
$config = Import-PowerShellDataFile -Path $ConfigFile

# Validate configuration
if (-not $config.Server) {
    Write-Host "[ERROR] Server not configured" -ForegroundColor Red
    exit 1
}

if (-not $config.Credentials -or -not $config.Credentials.Username -or -not $config.Credentials.Password) {
    Write-Host "[ERROR] Credentials not configured" -ForegroundColor Red
    exit 1
}

if (-not $config.Endpoints -or $config.Endpoints.Count -eq 0) {
    Write-Host "[ERROR] No endpoints configured" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Configuration loaded" -ForegroundColor Green
Write-Host "  Server: $($config.Server)" -ForegroundColor Gray
Write-Host "  Username: $($config.Credentials.Username)" -ForegroundColor Gray
Write-Host "  Endpoints: $($config.Endpoints.Count)" -ForegroundColor Gray
Write-Host ""

# Get authentication token
Write-Host "Step 1: Retrieving token..." -ForegroundColor Yellow
$token = Get-AuthTokenFromWpms -Username $config.Credentials.Username -Password $config.Credentials.Password

if (-not $token) {
    Write-Host "[ERROR] Failed to retrieve token" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Token obtained" -ForegroundColor Green
Write-Host ""

# Prepare output file
if (-not $OutputFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputFile = "$PSScriptRoot\test-results-$timestamp.csv"
}

Write-Host "Results will be written to: $OutputFile" -ForegroundColor Gray
Write-Host ""

# Array to store results
$results = @()

# Call each endpoint
$totalEndpoints = $config.Endpoints.Count
$successCount = 0
$failureCount = 0

for ($i = 0; $i -lt $totalEndpoints; $i++) {
    $endpoint = $config.Endpoints[$i]
    $endpointNum = $i + 1
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Endpoint $endpointNum of $totalEndpoints" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Name: $($endpoint.Name)" -ForegroundColor Yellow
    Write-Host "URI: $($endpoint.Uri)" -ForegroundColor Gray
    
    if ($endpoint.Parameters -and $endpoint.Parameters.Count -gt 0) {
        Write-Host "Parameters:" -ForegroundColor Gray
        foreach ($key in $endpoint.Parameters.Keys) {
            Write-Host "  $key = $($endpoint.Parameters[$key])" -ForegroundColor Gray
        }
    } else {
        Write-Host "Parameters: (none)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Build full URI
    $fullUri = "$($config.Server)$($endpoint.Uri)"
    
    # Make API call
    if ($endpoint.Parameters -and $endpoint.Parameters.Count -gt 0) {
        $response = Invoke-RestApiRequest `
            -Method GET `
            -Uri $fullUri `
            -QueryParameters $endpoint.Parameters `
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
    
    # Prepare result object
    $resultObj = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        EndpointNumber = $endpointNum
        Name = $endpoint.Name
        Uri = $endpoint.Uri
        FullUri = $fullUri
        Parameters = if ($endpoint.Parameters -and $endpoint.Parameters.Count -gt 0) {
            ($endpoint.Parameters.Keys | ForEach-Object { "$_=$($endpoint.Parameters[$_])" }) -join "; "
        } else {
            "(none)"
        }
        Success = $response.Success
        StatusCode = $response.StatusCode
        ItemCount = 0
        ErrorMessage = $response.Error
    }
    
    if ($response.Success) {
        Write-Host "[OK] Request successful" -ForegroundColor Green
        Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Cyan
        $successCount++
        
        if ($response.Content) {
            $itemCount = 0
            if ($response.Content -is [array]) {
                $itemCount = $response.Content.Count
            } else {
                $itemCount = 1
            }
            $resultObj.ItemCount = $itemCount
            Write-Host "Response: $itemCount item(s) returned" -ForegroundColor Gray
        } else {
            Write-Host "Response: Empty or non-JSON" -ForegroundColor Gray
        }
    } else {
        Write-Host "[ERROR] Request failed" -ForegroundColor Red
        Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Cyan
        Write-Host "Error: $($response.Error)" -ForegroundColor Red
        $failureCount++
    }
    
    # Add to results array
    $results += $resultObj
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total endpoints: $totalEndpoints" -ForegroundColor Gray
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor Red
Write-Host ""

# Write results to CSV
try {
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "[OK] Results written to: $OutputFile" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to write CSV: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

if ($failureCount -eq 0) {
    Write-Host "All API calls completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some API calls failed. Please review the output above." -ForegroundColor Yellow
    exit 1
}
