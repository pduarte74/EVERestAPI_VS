#!/usr/bin/env powershell
<#
.SYNOPSIS
    Historical data import script for MOV_ESTAT_PRODUTIVIDADE
.DESCRIPTION
    Retrieves historical productivity data from WPMS API starting from a specified date
    and imports it into the MOV_ESTAT_PRODUTIVIDADE table.
.PARAMETER StartDate
    Start date for historical data retrieval (format: yyyyMMdd, default: 20250101)
.PARAMETER EndDate
    End date for historical data retrieval (format: yyyyMMdd, default: today)
.PARAMETER ConfigFile
    Path to the configuration file (default: ..\config\api-config.psd1)
.PARAMETER SqlConnectionString
    SQL Server connection string (overrides config file if provided)
.PARAMETER ClearExistingData
    If specified, clears existing MOV_ESTAT_PRODUTIVIDADE table before import
.PARAMETER DryRun
    If specified, performs validation without making database changes
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$StartDate = "20250101",
    
    [Parameter(Mandatory=$false)]
    [string]$EndDate,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "$PSScriptRoot\..\config\api-config.psd1",
    
    [Parameter(Mandatory=$false)]
    [string]$SqlConnectionString,
    
    [Parameter(Mandatory=$false)]
    [switch]$ClearExistingData,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Import modules
. "$PSScriptRoot\Get-AuthToken.ps1"
. "$PSScriptRoot\RestClient.ps1"

# Set default end date to today
if ([string]::IsNullOrEmpty($EndDate)) {
    $EndDate = (Get-Date).ToString("yyyyMMdd")
}

Write-Host "=== MOV_ESTAT_PRODUTIVIDADE Historical Data Import ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Date Range: $StartDate to $EndDate" -ForegroundColor White
if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes will be made)" -ForegroundColor Yellow
}
Write-Host ""

# Validate dates
try {
    $startDateTime = [datetime]::ParseExact($StartDate, 'yyyyMMdd', $null)
    $endDateTime = [datetime]::ParseExact($EndDate, 'yyyyMMdd', $null)
    
    if ($startDateTime -gt $endDateTime) {
        Write-Host "ERROR: Start date cannot be after end date" -ForegroundColor Red
        exit 1
    }
    
    $dayCount = ($endDateTime - $startDateTime).Days + 1
    Write-Host "Importing data for $dayCount days..." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "ERROR: Invalid date format. Use yyyyMMdd (e.g., 20250101)" -ForegroundColor Red
    exit 1
}

# Load configuration
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: Configuration file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

Write-Host "[1/5] Loading configuration..." -ForegroundColor Yellow
try {
    $config = Import-PowerShellDataFile -Path $ConfigFile
} catch {
    Write-Host "ERROR: Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load password from secure file
$password = $null
if ($config.Credentials.SecurePasswordFile) {
    $securePasswordPath = Join-Path (Split-Path -Parent $ConfigFile) $config.Credentials.SecurePasswordFile
    if (Test-Path $securePasswordPath) {
        try {
            $encryptedPassword = Get-Content -Path $securePasswordPath | ConvertTo-SecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptedPassword)
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        } catch {
            Write-Host "ERROR: Failed to decrypt password: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR: Secure password file not found: $securePasswordPath" -ForegroundColor Red
        exit 1
    }
} elseif ($config.Credentials.Password) {
    $password = $config.Credentials.Password
} else {
    Write-Host "ERROR: No password configured" -ForegroundColor Red
    exit 1
}

Write-Host "  Configuration loaded successfully" -ForegroundColor Green

# Get authentication token
Write-Host ""
Write-Host "[2/5] Authenticating with WPMS API..." -ForegroundColor Yellow
try {
    $loginEndpoint = "$($config.Server)/Eve/api/login"
    $token = Get-AuthTokenFromWpms -Username $config.Credentials.Username -Password $password -Endpoint $loginEndpoint
    
    if (-not $token) {
        Write-Host "ERROR: Failed to retrieve authentication token" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Authentication successful" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Connect to SQL
Write-Host ""
Write-Host "[3/5] Connecting to SQL Server..." -ForegroundColor Yellow

$effectiveSqlConnectionString = if ($SqlConnectionString) { $SqlConnectionString } elseif ($config.SqlConnectionString) { $config.SqlConnectionString } else { $null }

if (-not $effectiveSqlConnectionString) {
    Write-Host "ERROR: No SQL connection string provided" -ForegroundColor Red
    exit 1
}

try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $effectiveSqlConnectionString
    $sqlConnection.Open()
    Write-Host "  SQL connection successful" -ForegroundColor Green
} catch {
    Write-Host "ERROR: SQL connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Load endpoint configuration
Write-Host ""
Write-Host "[4/5] Loading endpoint configuration..." -ForegroundColor Yellow

$configDir = Split-Path -Parent $ConfigFile
$endpointPath = Join-Path $configDir "endpoints\MOV_ESTAT_PRODUTIVIDADE.psd1"

if (-not (Test-Path $endpointPath)) {
    Write-Host "ERROR: Endpoint configuration not found: $endpointPath" -ForegroundColor Red
    $sqlConnection.Close()
    exit 1
}

try {
    $endpoint = Import-PowerShellDataFile -Path $endpointPath
    Write-Host "  Endpoint configuration loaded" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to load endpoint configuration: $($_.Exception.Message)" -ForegroundColor Red
    $sqlConnection.Close()
    exit 1
}

# Clear existing data if requested
if ($ClearExistingData -and -not $DryRun) {
    Write-Host ""
    Write-Host "Clearing existing data from MOV_ESTAT_PRODUTIVIDADE..." -ForegroundColor Yellow
    try {
        $deleteCmd = $sqlConnection.CreateCommand()
        $deleteCmd.CommandText = "DELETE FROM dbo.MOV_ESTAT_PRODUTIVIDADE"
        $deletedRows = $deleteCmd.ExecuteNonQuery()
        Write-Host "  Deleted $deletedRows rows" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to clear table: $($_.Exception.Message)" -ForegroundColor Red
        $sqlConnection.Close()
        exit 1
    }
}

# Retrieve data for each date
Write-Host ""
Write-Host "[5/5] Retrieving historical data..." -ForegroundColor Yellow
Write-Host ""

$totalRecords = 0
$totalErrors = 0
$currentDate = $startDateTime

while ($currentDate -le $endDateTime) {
    $dateStr = $currentDate.ToString("yyyyMMdd")
    $dayName = $currentDate.ToString("dddd")
    
    Write-Host "Processing $dateStr ($dayName)..." -ForegroundColor Cyan
    
    # Prepare parameters for this date
    $params = @{
        DTVL = @{ val1 = $dateStr }
        ENTI = @{ val1 = "('92','93')"; sig1 = "IN" }
    }
    
    # Build URI with query parameters
    $uri = $endpoint.Uri
    $httpMethod = $endpoint.Method
    
    # Build query string - convert hashtable to JSON for each parameter
    $queryParams = @()
    foreach ($key in $params.Keys) {
        $paramObj = $params[$key]
        $paramJson = ConvertTo-Json -InputObject $paramObj -Compress
        $encodedParam = [System.Uri]::EscapeDataString($paramJson)
        $queryParams += "$key=$encodedParam"
    }
    $fullUri = $uri + "?" + ($queryParams -join "&")
    
    try {
        # Call API with GET and parameters in query string
        $response = Invoke-WebRequest -Uri "$($config.Server)$fullUri" `
            -Method $httpMethod `
            -Headers @{ 'Authorization' = "Bearer $token" } `
            -UseBasicParsing
        
        $jsonResponse = $response.Content | ConvertFrom-Json
        
        # Extract data from numbered-key format
        $dataItems = @()
        foreach ($key in $jsonResponse.PSObject.Properties.Name) {
            if ($key -match '^\d+$') {
                $dataItems += $jsonResponse.$key
            }
        }
        
        $itemCount = $dataItems.Count
        
        if ($itemCount -eq 0) {
            Write-Host "  OK No records for this date" -ForegroundColor Gray
        } else {
            Write-Host "  Retrieved $itemCount records" -ForegroundColor Green
            
            # Upsert data (MERGE to avoid PK conflicts)
            if (-not $DryRun) {
                try {
                    $insertedCount = 0
                    foreach ($row in $dataItems) {
                        # Prepare field mappings
                        $fieldMappings = @{
                            'Whrs' = 'Whrs'
                            'Oprt' = 'Oprt'
                            'WrkType' = 'WrkType'
                            'Dprt' = 'Dprt'
                            'Shift' = 'Shift'
                            'Team' = 'Team'
                            'QttPicked' = 'QttPicked'
                            'QttPicked2' = 'QttPicked2'
                            'QttChecked' = 'QttChecked'
                            'QttChecked2' = 'QttChecked2'
                            'QttCounted' = 'QttCounted'
                            'QttCounted2' = 'QttCounted2'
                            'TimeSpent' = 'TimeSpent'
                            'TimeUm' = 'TimeUm'
                            'NrSusp' = 'NrSusp'
                            'NrActions' = 'NrActions'
                            'NrContainers' = 'NrContainers'
                            'HorizDistance' = 'HorizDistance'
                            'VertDistance' = 'VertDistance'
                            'Numero_linee' = 'Numero_linee'
                            'DistUM' = 'DistUM'
                            'DifQtt' = 'DifQtt'
                            'DiffQtt2' = 'DiffQtt2'
                            'NrErrors' = 'NrErrors'
                        }

                        $pkColumns = @('Date','Whrs','Oprt','WrkType')
                        $allFields = @('Date') + $fieldMappings.Keys

                        $insertColumns = $allFields + 'RetrievedAt'
                        $insertValues = $insertColumns.ForEach({ '@' + $_ })
                        $updateSet = ($allFields | Where-Object { $_ -notin $pkColumns } | ForEach-Object { "[{0}] = @{0}" -f $_ }) -join ', '
                        $sourceSelect = ($allFields | ForEach-Object { "@{0} AS [{0}]" -f $_ }) -join ', '
                        $pkCondition = ($pkColumns | ForEach-Object { "target.[{0}] = source.[{0}]" -f $_ }) -join ' AND '

                        $cmd = $sqlConnection.CreateCommand()
                        $cmd.CommandText = "MERGE INTO [dbo].[MOV_ESTAT_PRODUTIVIDADE] AS target
USING (SELECT $sourceSelect) AS source
ON $pkCondition
WHEN MATCHED THEN
    UPDATE SET $updateSet, RetrievedAt = @RetrievedAt
WHEN NOT MATCHED THEN
    INSERT ($($insertColumns -join ', '))
    VALUES ($($insertValues -join ', '));"

                        # Set parameters
                        $cmd.Parameters.AddWithValue("@Date", [datetime]::ParseExact($dateStr, 'yyyyMMdd', $null)) | Out-Null

                        foreach ($field in $fieldMappings.Keys) {
                            $value = if ($row.PSObject.Properties[$field]) { $row.$field } else { $null }

                            # Apply data type conversions
                            if ($null -ne $value -and $value -ne '') {
                                $colDef = $endpoint.TableSchema.Columns | Where-Object { $_.Name -eq $fieldMappings[$field] } | Select-Object -First 1
                                if ($colDef) {
                                    switch -Regex ($colDef.Type) {
                                        '^(INT|BIGINT|SMALLINT|TINYINT)$' {
                                            try {
                                                $value = [int]$value
                                            } catch {
                                                $value = [DBNull]::Value
                                            }
                                        }
                                        '^(DECIMAL|NUMERIC|FLOAT|REAL)' {
                                            try {
                                                $value = [decimal]$value
                                            } catch {
                                                $value = [DBNull]::Value
                                            }
                                        }
                                    }
                                }
                            }

                            $cmd.Parameters.AddWithValue("@$field", $(if ($null -eq $value -or $value -eq '') { [DBNull]::Value } else { $value })) | Out-Null
                        }

                        $cmd.Parameters.AddWithValue("@RetrievedAt", (Get-Date)) | Out-Null
                        $cmd.ExecuteNonQuery() | Out-Null
                        $insertedCount++
                    }

                    $totalRecords += $insertedCount
                    Write-Host "  OK Inserted/updated $insertedCount records" -ForegroundColor Green
                } catch {
                    Write-Host "  ERROR Error inserting data: $($_.Exception.Message)" -ForegroundColor Red
                    $totalErrors++
                }
            } else {
                # Dry run - just count records
                $totalRecords += $itemCount
                Write-Host "  [DRY RUN] Would insert $itemCount records" -ForegroundColor Cyan
            }
        }
    } catch {
        Write-Host "  ERROR Error retrieving data: $($_.Exception.Message)" -ForegroundColor Red
        $totalErrors++
    }
    
    $currentDate = $currentDate.AddDays(1)
}

$sqlConnection.Close()

# Summary
Write-Host ""
Write-Host "=== Import Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total records processed: $totalRecords" -ForegroundColor White
Write-Host "Errors encountered: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { 'Yellow' } else { 'Green' })

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN completed. No changes made to the database." -ForegroundColor Yellow
    Write-Host "Run without -DryRun flag to import the data." -ForegroundColor Gray
}

Write-Host ""

if ($totalErrors -eq 0) {
    exit 0
} else {
    exit 1
}
