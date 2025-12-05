#!/usr/bin/env powershell
<#
.SYNOPSIS
    Production script for WPMS API integration
.DESCRIPTION
    Reads configuration file with credentials, endpoints and parameters,
    then calls each configured API endpoint and logs results to a log file.
.PARAMETER ConfigFile
    Path to the configuration file (default: ..\config\api-config.psd1)
.PARAMETER LogFile
    Path to the log file (default: wpms-api-TIMESTAMP.log)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "$PSScriptRoot\..\config\api-config.psd1",
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile
)

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

# Helper function to write log
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logEntry
    
    # Also write to console with color
    switch ($Level) {
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        default   { Write-Host $logEntry -ForegroundColor Gray }
    }
}

Write-Host "=== WPMS API Production Runner ===" -ForegroundColor Cyan
Write-Host ""

# Prepare log file in dedicated folder (defaults to ..\logs)
if (-not $LogFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogFile = [System.IO.Path]::Combine($PSScriptRoot, '..', 'logs', "wpms-api-$timestamp.log")
}

# Ensure log directory exists
try {
    $logDir = Split-Path -Parent $LogFile
    if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
} catch {
    Write-Host "[ERROR] Failed to ensure log directory: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create log file
try {
    $script:LogFile = [System.IO.Path]::GetFullPath($LogFile)
    New-Item -Path $script:LogFile -ItemType File -Force | Out-Null
    Write-Host "Log file: $script:LogFile" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "[ERROR] Failed to create log file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Log "========================================" -Level INFO
Write-Log "WPMS API Production Run Started" -Level INFO
Write-Log "========================================" -Level INFO

# Load configuration
if (-not (Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level ERROR
    exit 1
}

Write-Log "Loading configuration from: $ConfigFile" -Level INFO
try {
    $config = Import-PowerShellDataFile -Path $ConfigFile
} catch {
    Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level ERROR
    exit 1
}

# Validate configuration
if (-not $config.Server) {
    Write-Log "Server not configured" -Level ERROR
    exit 1
}

if (-not $config.Credentials -or -not $config.Credentials.Username -or -not $config.Credentials.Password) {
    Write-Log "Credentials not configured" -Level ERROR
    exit 1
}

if (-not $config.Endpoints -or $config.Endpoints.Count -eq 0) {
    Write-Log "No endpoints configured" -Level ERROR
    exit 1
}

Write-Log "Configuration loaded successfully" -Level SUCCESS
Write-Log "  Server: $($config.Server)" -Level INFO
Write-Log "  Username: $($config.Credentials.Username)" -Level INFO
Write-Log "  Endpoints: $($config.Endpoints.Count)" -Level INFO

# Get authentication token
Write-Log "Retrieving authentication token..." -Level INFO
try {
    $token = Get-AuthTokenFromWpms -Username $config.Credentials.Username -Password $config.Credentials.Password
    
    if (-not $token) {
        Write-Log "Failed to retrieve authentication token" -Level ERROR
        exit 1
    }
    
    Write-Log "Authentication token obtained successfully" -Level SUCCESS
} catch {
    Write-Log "Error retrieving token: $($_.Exception.Message)" -Level ERROR
    exit 1
}

# Call each endpoint
$totalEndpoints = $config.Endpoints.Count
$successCount = 0
$failureCount = 0

Write-Log "Starting API calls for $totalEndpoints endpoint(s)..." -Level INFO

for ($i = 0; $i -lt $totalEndpoints; $i++) {
    $endpoint = $config.Endpoints[$i]
    $endpointNum = $i + 1
    
    Write-Log "----------------------------------------" -Level INFO
    Write-Log "Endpoint $endpointNum of $totalEndpoints - $($endpoint.Name)" -Level INFO
    Write-Log "  URI: $($endpoint.Uri)" -Level INFO
    
    # Log parameters
    if ($endpoint.Parameters -and $endpoint.Parameters.Count -gt 0) {
        foreach ($key in $endpoint.Parameters.Keys) {
            Write-Log "  Parameter: $key = $($endpoint.Parameters[$key])" -Level INFO
        }
    } else {
        Write-Log "  Parameters: (none)" -Level INFO
    }
    
    # Build full URI
    $fullUri = "$($config.Server)$($endpoint.Uri)"
    Write-Log "  Full URI: $fullUri" -Level INFO
    
    # Make API call
    try {
        if ($endpoint.Parameters -and $endpoint.Parameters.Count -gt 0) {
            $response = Invoke-RestApiRequest `
                -Method GET `
                -Uri $fullUri `
                -QueryParameters $endpoint.Parameters `
                -BearerToken $token
        } else {
            $response = Invoke-RestApiRequest `
                -Method GET `
                -Uri $fullUri `
                -BearerToken $token
        }
        
        if ($response.Success) {
            $itemCount = 0
            if ($response.Content) {
                if ($response.Content -is [array]) {
                    $itemCount = $response.Content.Count
                } else {
                    $itemCount = 1
                }
            }
            
            Write-Log "  Status: SUCCESS (HTTP $($response.StatusCode))" -Level SUCCESS
            Write-Log "  Items returned: $itemCount" -Level INFO
            $successCount++
        } else {
            Write-Log "  Status: FAILED (HTTP $($response.StatusCode))" -Level ERROR
            Write-Log "  Error: $($response.Error)" -Level ERROR
            $failureCount++
        }
    } catch {
        Write-Log "  Status: EXCEPTION" -Level ERROR
        Write-Log "  Error: $($_.Exception.Message)" -Level ERROR
        $failureCount++
    }
}

# Summary
Write-Log "========================================" -Level INFO
Write-Log "WPMS API Production Run Completed" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Total endpoints: $totalEndpoints" -Level INFO
Write-Log "Successful: $successCount" -Level SUCCESS
Write-Log "Failed: $failureCount" -Level $(if ($failureCount -eq 0) { 'SUCCESS' } else { 'ERROR' })
Write-Log "Log file: $LogFile" -Level INFO

Write-Host ""
if ($failureCount -eq 0) {
    Write-Host "All API calls completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some API calls failed. Check log file for details: $LogFile" -ForegroundColor Yellow
    exit 1
}
