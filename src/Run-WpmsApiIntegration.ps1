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
    [string]$LogFile,

    [Parameter(Mandatory=$false)]
    [string]$SqlConnectionString,

    [Parameter(Mandatory=$false)]
    [string]$SqlTable = 'dbo.WpmsApiResults'
)

# Import modules
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"
. "$PSScriptRoot\..\src\RestClient.ps1"

# SQL helper functions
function Ensure-SqlTable {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SchemaName,
        [string]$TableName
    )

    # Ensure target table exists with a simple schema for JSON payloads
    $safeSchema = $SchemaName.Replace("'", "''")
    $safeTable = $TableName.Replace("'", "''")
    $ddl = @"
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = N'$safeTable' AND s.name = N'$safeSchema'
)
BEGIN
    EXEC('CREATE TABLE [$safeSchema].[$safeTable] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EndpointName] NVARCHAR(200) NOT NULL,
        [FullUri] NVARCHAR(4000) NULL,
        [RetrievedAt] DATETIME2(3) NOT NULL,
        [StatusCode] INT NULL,
        [Success] BIT NOT NULL,
        [ItemCount] INT NULL,
        [Payload] NVARCHAR(MAX) NULL
    )');
END
"@

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $ddl
    $cmd.ExecuteNonQuery() | Out-Null
}

function Write-SqlResult {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SchemaName,
        [string]$TableName,
        [string]$EndpointName,
        [string]$FullUri,
        [datetime]$RetrievedAt,
        [int]$StatusCode,
        [bool]$Success,
        [int]$ItemCount,
        [string]$Payload
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "INSERT INTO [$SchemaName].[$TableName] (EndpointName, FullUri, RetrievedAt, StatusCode, Success, ItemCount, Payload) VALUES (@EndpointName, @FullUri, @RetrievedAt, @StatusCode, @Success, @ItemCount, @Payload)"

    $null = $cmd.Parameters.Add('@EndpointName', [System.Data.SqlDbType]::NVarChar, 200)
    $null = $cmd.Parameters.Add('@FullUri', [System.Data.SqlDbType]::NVarChar, 4000)
    $null = $cmd.Parameters.Add('@RetrievedAt', [System.Data.SqlDbType]::DateTime2)
    $null = $cmd.Parameters.Add('@StatusCode', [System.Data.SqlDbType]::Int)
    $null = $cmd.Parameters.Add('@Success', [System.Data.SqlDbType]::Bit)
    $null = $cmd.Parameters.Add('@ItemCount', [System.Data.SqlDbType]::Int)
    $null = $cmd.Parameters.Add('@Payload', [System.Data.SqlDbType]::NVarChar, -1)

    $cmd.Parameters['@EndpointName'].Value = $EndpointName
    $cmd.Parameters['@FullUri'].Value = $FullUri
    $cmd.Parameters['@RetrievedAt'].Value = $RetrievedAt
    $cmd.Parameters['@StatusCode'].Value = if ($null -eq $StatusCode) { [DBNull]::Value } else { $StatusCode }
    $cmd.Parameters['@Success'].Value = $Success
    $cmd.Parameters['@ItemCount'].Value = $ItemCount
    $cmd.Parameters['@Payload'].Value = if ($null -eq $Payload) { [DBNull]::Value } else { $Payload }

    $cmd.ExecuteNonQuery() | Out-Null
}

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

# Optional SQL setup
$sqlConnection = $null
$schemaName = 'dbo'
$tableName = 'WpmsApiResults'
if ($SqlTable) {
    $parts = $SqlTable.Split('.', 2)
    if ($parts.Count -eq 2) {
        $schemaName = $parts[0]
        $tableName = $parts[1]
    } else {
        $tableName = $SqlTable
    }
}

if ($SqlConnectionString) {
    Write-Log "SQL: Connecting..." -Level INFO
    try {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $SqlConnectionString
        $sqlConnection.Open()
        Ensure-SqlTable -Connection $sqlConnection -SchemaName $schemaName -TableName $tableName
        Write-Log "SQL: Ready -> [$schemaName].[$tableName]" -Level SUCCESS
    } catch {
        Write-Log "SQL initialization failed: $($_.Exception.Message)" -Level ERROR
        $sqlConnection = $null
    }
} else {
    Write-Log "SQL: Disabled (no connection string provided)" -Level INFO
}

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
    
    $response = $null
    $statusCode = $null
    $itemCount = 0
    $payloadForSql = $null
    $retrievedAt = Get-Date
    $successFlag = $false

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

        $statusCode = $response.StatusCode

        if ($response.Success) {
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
            $successFlag = $true
            if ($response.Content) {
                $payloadForSql = $response.Content | ConvertTo-Json -Depth 12
            } elseif ($response.RawContent) {
                $payloadForSql = $response.RawContent
            }
        } else {
            Write-Log "  Status: FAILED (HTTP $($response.StatusCode))" -Level ERROR
            Write-Log "  Error: $($response.Error)" -Level ERROR
            $failureCount++
            $payloadForSql = if ($response.Error) { $response.Error } else { $response.RawContent }
        }
    } catch {
        Write-Log "  Status: EXCEPTION" -Level ERROR
        Write-Log "  Error: $($_.Exception.Message)" -Level ERROR
        $failureCount++
        $payloadForSql = $_.Exception.Message
    }

    if ($sqlConnection) {
        try {
            if (-not $payloadForSql -and $response -and $response.RawContent) {
                $payloadForSql = $response.RawContent
            }

            Write-SqlResult `
                -Connection $sqlConnection `
                -SchemaName $schemaName `
                -TableName $tableName `
                -EndpointName $endpoint.Name `
                -FullUri $fullUri `
                -RetrievedAt $retrievedAt `
                -StatusCode $statusCode `
                -Success $successFlag `
                -ItemCount $itemCount `
                -Payload $payloadForSql

            Write-Log "  SQL write: OK -> [$schemaName].[$tableName]" -Level SUCCESS
        } catch {
            Write-Log "  SQL write failed: $($_.Exception.Message)" -Level ERROR
        }
    }
}

if ($sqlConnection) {
    try {
        $sqlConnection.Close()
        Write-Log "SQL: Connection closed" -Level INFO
    } catch {
        Write-Log "SQL: Error while closing connection: $($_.Exception.Message)" -Level WARNING
    }
}

# Summary
Write-Log "========================================" -Level INFO
Write-Log "WPMS API Production Run Completed" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Total endpoints: $totalEndpoints" -Level INFO
Write-Log "Successful: $successCount" -Level SUCCESS
Write-Log "Failed: $failureCount" -Level $(if ($failureCount -eq 0) { 'SUCCESS' } else { 'ERROR' })
Write-Log "Log file: $script:LogFile" -Level INFO

Write-Host ""
if ($failureCount -eq 0) {
    Write-Host "All API calls completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some API calls failed. Check log file for details: $LogFile" -ForegroundColor Yellow
    exit 1
}
