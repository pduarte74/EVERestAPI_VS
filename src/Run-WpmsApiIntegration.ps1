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
        [string]$TableName,
        [switch]$IsLogTable,
        [hashtable]$TableSchema
    )

    $safeSchema = $SchemaName.Replace("'", "''")
    $safeTable = $TableName.Replace("'", "''")
    
    if ($IsLogTable) {
        # Log table for WpmsApiResults - stores JSON payloads
        $ddl = @"
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = N'$safeTable' AND s.name = N'$safeSchema'
)
BEGIN
    CREATE TABLE [$safeSchema].[$safeTable] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EndpointName] NVARCHAR(200) NOT NULL,
        [FullUri] NVARCHAR(4000) NULL,
        [RetrievedAt] DATETIME2(3) NOT NULL,
        [StatusCode] INT NULL,
        [Success] BIT NOT NULL,
        [ItemCount] INT NULL,
        [Payload] NVARCHAR(MAX) NULL
    );
END
"@
    } elseif ($TableSchema -and $TableSchema.Columns) {
        # Build dynamic table from schema definition
        $columnDefs = @()
        $pkColumns = @()
        
        foreach ($col in $TableSchema.Columns) {
            $colName = $col.Name
            $colType = $col.Type
            $nullable = if ($col.PrimaryKey -or $col.Default) { "NOT NULL" } else { "NULL" }
            $default = if ($col.Default) { " DEFAULT $($col.Default)" } else { "" }
            
            $columnDefs += "        [$colName] $colType $nullable$default"
            
            if ($col.PrimaryKey) {
                $pkColumns += "[$colName]"
            }
        }
        
        if ($pkColumns.Count -gt 0) {
            $columnDefs += "        PRIMARY KEY ($($pkColumns -join ', '))"
        }
        
        $columnsStr = $columnDefs -join ",`n"
        
        $ddl = @"
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = N'$safeTable' AND s.name = N'$safeSchema'
)
BEGIN
    CREATE TABLE [$safeSchema].[$safeTable] (
$columnsStr
    );
END
"@
    } else {
        throw "Table schema not provided for data table"
    }

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

function Write-EndpointData {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SchemaName,
        [string]$TableName,
        [object[]]$DataRows,
        [datetime]$RetrievedAt,
        [hashtable]$FieldMappings,
        [hashtable]$TableSchema
    )

    if (-not $FieldMappings -or -not $TableSchema) {
        throw "FieldMappings and TableSchema are required"
    }

    # Get primary key columns
    $pkColumns = @()
    foreach ($col in $TableSchema.Columns) {
        if ($col.PrimaryKey) {
            $pkColumns += $col.Name
        }
    }

    if ($pkColumns.Count -eq 0) {
        throw "No primary key defined in table schema"
    }

    # Build field lists
    $allFields = $FieldMappings.Keys | Where-Object { $_ -ne 'RetrievedAt' }
    $updateSetClauses = @()
    $insertColumns = @()
    $insertValues = @()

    foreach ($field in $allFields) {
        $colName = $FieldMappings[$field]
        if ($pkColumns -notcontains $colName) {
            $updateSetClauses += "$colName = @$field"
        }
        $insertColumns += $colName
        $insertValues += "@$field"
    }

    # Add RetrievedAt
    $insertColumns += "RetrievedAt"
    $insertValues += "@RetrievedAt"
    $updateSetClauses += "RetrievedAt = @RetrievedAt"

    # Build MERGE statement
    $pkCondition = ($pkColumns | ForEach-Object { "target.$_ = source.$_" }) -join " AND "
    $sourceSelect = ($pkColumns | ForEach-Object { "@$_ AS $_" }) -join ", "

    $mergeQuery = @"
MERGE INTO [$SchemaName].[$TableName] AS target
USING (SELECT $sourceSelect) AS source
ON $pkCondition
WHEN MATCHED THEN
    UPDATE SET $($updateSetClauses -join ', ')
WHEN NOT MATCHED THEN
    INSERT ($($insertColumns -join ', '))
    VALUES ($($insertValues -join ', '));
"@

    foreach ($row in $DataRows) {
        $cmd = $Connection.CreateCommand()
        $cmd.CommandText = $mergeQuery

        foreach ($field in $allFields) {
            $value = if ($row.PSObject.Properties[$field]) { $row.$field } else { $null }
            
            # Apply data type conversions based on TableSchema
            if ($null -ne $value -and $value -ne '') {
                $colDef = $TableSchema.Columns | Where-Object { $_.Name -eq $FieldMappings[$field] } | Select-Object -First 1
                if ($colDef) {
                    switch -Regex ($colDef.Type) {
                        '^DATE$' {
                            # Convert from yyyyMMdd string to DATE
                            if ($value -match '^\d{8}$') {
                                try {
                                    $value = [datetime]::ParseExact($value, 'yyyyMMdd', $null)
                                } catch {
                                    $value = [DBNull]::Value
                                }
                            }
                        }
                        '^(INT|BIGINT|SMALLINT|TINYINT)$' {
                            # Convert to integer
                            try {
                                $value = [int]$value
                            } catch {
                                $value = [DBNull]::Value
                            }
                        }
                        '^(DECIMAL|NUMERIC|FLOAT|REAL)' {
                            # Convert to decimal/float
                            try {
                                $value = [decimal]$value
                            } catch {
                                $value = [DBNull]::Value
                            }
                        }
                    }
                }
            }
            
            $null = $cmd.Parameters.AddWithValue("@$field", $(if ($null -eq $value -or $value -eq '') { [DBNull]::Value } else { $value }))
        }

        $null = $cmd.Parameters.AddWithValue('@RetrievedAt', $RetrievedAt)

        $cmd.ExecuteNonQuery() | Out-Null
    }
}

function Write-TmUsersData {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SchemaName,
        [string]$TableName,
        [object[]]$DataRows,
        [datetime]$RetrievedAt
    )

    foreach ($row in $DataRows) {
        $cmd = $Connection.CreateCommand()
        $cmd.CommandText = @"
MERGE INTO [$SchemaName].[$TableName] AS target
USING (SELECT @Utente AS Utente) AS source
ON target.Utente = source.Utente
WHEN MATCHED THEN
    UPDATE SET
        Utente_nome = @Utente_nome,
        Utente_adm = @Utente_adm,
        Utente_gruppo = @Utente_gruppo,
        Lingua_codice = @Lingua_codice,
        Menu_rf = @Menu_rf,
        Menu_codice = @Menu_codice,
        Password_no_rule = @Password_no_rule,
        Trace_accesso = @Trace_accesso,
        Codice_validazione = @Codice_validazione,
        Installazione = @Installazione,
        Preferenze = @Preferenze,
        Style_sheet = @Style_sheet,
        Std_datamod = @Std_datamod,
        Std_utente = @Std_utente,
        RetrievedAt = @RetrievedAt
WHEN NOT MATCHED THEN
    INSERT (Utente, Utente_nome, Utente_adm, Utente_gruppo, Lingua_codice, Menu_rf, Menu_codice, 
            Password_no_rule, Trace_accesso, Codice_validazione, Installazione, Preferenze, 
            Style_sheet, Std_datamod, Std_utente, RetrievedAt)
    VALUES (@Utente, @Utente_nome, @Utente_adm, @Utente_gruppo, @Lingua_codice, @Menu_rf, @Menu_codice,
            @Password_no_rule, @Trace_accesso, @Codice_validazione, @Installazione, @Preferenze,
            @Style_sheet, @Std_datamod, @Std_utente, @RetrievedAt);
"@

        $null = $cmd.Parameters.AddWithValue('@Utente', $(if ($row.Utente) { $row.Utente } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Utente_nome', $(if ($row.Utente_nome) { $row.Utente_nome } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Utente_adm', $(if ($row.Utente_adm) { $row.Utente_adm } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Utente_gruppo', $(if ($row.Utente_gruppo) { $row.Utente_gruppo } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Lingua_codice', $(if ($row.Lingua_codice) { $row.Lingua_codice } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Menu_rf', $(if ($row.Menu_rf) { $row.Menu_rf } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Menu_codice', $(if ($row.Menu_codice) { $row.Menu_codice } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Password_no_rule', $(if ($row.Password_no_rule) { $row.Password_no_rule } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Trace_accesso', $(if ($row.Trace_accesso) { $row.Trace_accesso } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Codice_validazione', $(if ($row.Codice_validazione) { $row.Codice_validazione } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Installazione', $(if ($row.Installazione) { $row.Installazione } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Preferenze', $(if ($row.Preferenze) { $row.Preferenze } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Style_sheet', $(if ($row.Style_sheet) { $row.Style_sheet } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Std_datamod', $(if ($row.Std_datamod) { $row.Std_datamod } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@Std_utente', $(if ($row.Std_utente) { $row.Std_utente } else { [DBNull]::Value }))
        $null = $cmd.Parameters.AddWithValue('@RetrievedAt', $RetrievedAt)

        $cmd.ExecuteNonQuery() | Out-Null
    }
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

# Load endpoints from separate config files if specified
$endpoints = @()
if ($config.EndpointConfigFiles -and $config.EndpointConfigFiles.Count -gt 0) {
    $configDir = Split-Path -Parent $ConfigFile
    foreach ($endpointFile in $config.EndpointConfigFiles) {
        $endpointPath = Join-Path $configDir $endpointFile
        if (Test-Path $endpointPath) {
            try {
                $endpoint = Import-PowerShellDataFile -Path $endpointPath
                
                # Process dynamic parameter values
                if ($endpoint.Parameters) {
                    $paramKeys = @($endpoint.Parameters.Keys)
                    foreach ($paramKey in $paramKeys) {
                        $paramValue = $endpoint.Parameters[$paramKey]
                        if ($paramValue -is [hashtable]) {
                            $valueKeys = @($paramValue.Keys)
                            foreach ($valueKey in $valueKeys) {
                                $value = $paramValue[$valueKey]
                                if ($value -is [string] -and $value.StartsWith("DYNAMIC:")) {
                                    $dynamicType = $value.Substring(8)
                                    switch ($dynamicType) {
                                        "PreviousMondayDate" {
                                            # Calculate Monday of previous week
                                            $today = Get-Date
                                            $dayOfWeek = [int]$today.DayOfWeek
                                            # Get Monday of current week (0=Sunday, so Monday=1)
                                            $currentMonday = $today.AddDays(-($dayOfWeek - 1))
                                            # Subtract 7 days to get previous Monday
                                            $previousMonday = $currentMonday.AddDays(-7)
                                            $paramValue[$valueKey] = $previousMonday.ToString("yyyyMMdd")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                $endpoints += $endpoint
                Write-Log "  Loaded endpoint config: $endpointFile" -Level INFO
            } catch {
                Write-Log "  Failed to load endpoint config $endpointFile : $($_.Exception.Message)" -Level WARNING
            }
        } else {
            Write-Log "  Endpoint config not found: $endpointFile" -Level WARNING
        }
    }
} elseif ($config.Endpoints) {
    # Fallback to inline endpoints
    $endpoints = $config.Endpoints
}

if (-not $endpoints -or $endpoints.Count -eq 0) {
    Write-Log "No endpoints configured" -Level ERROR
    exit 1
}

# Update config with loaded endpoints for downstream processing
$config.Endpoints = $endpoints

Write-Log "Configuration loaded successfully" -Level SUCCESS
Write-Log "  Server: $($config.Server)" -Level INFO
Write-Log "  Username: $($config.Credentials.Username)" -Level INFO
Write-Log "  Endpoints: $($config.Endpoints.Count)" -Level INFO

# Optional SQL setup - prefer config file over command-line parameter
$effectiveSqlConnectionString = if ($SqlConnectionString) { $SqlConnectionString } elseif ($config.SqlConnectionString) { $config.SqlConnectionString } else { $null }
$defaultSqlTable = if ($SqlTable -ne 'dbo.WpmsApiResults') { $SqlTable } elseif ($config.SqlTable) { $config.SqlTable } else { 'dbo.WpmsApiResults' }

$sqlConnection = $null
$createdTables = @{}

if ($effectiveSqlConnectionString) {
    Write-Log "SQL: Connecting..." -Level INFO
    try {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $effectiveSqlConnectionString
        $sqlConnection.Open()
        
        # Ensure default table exists (log table)
        $parts = $defaultSqlTable.Split('.', 2)
        $defaultSchema = if ($parts.Count -eq 2) { $parts[0] } else { 'dbo' }
        $defaultTable = if ($parts.Count -eq 2) { $parts[1] } else { $defaultSqlTable }
        Ensure-SqlTable -Connection $sqlConnection -SchemaName $defaultSchema -TableName $defaultTable -IsLogTable
        $createdTables[$defaultSqlTable] = $true
        
        # Ensure all endpoint-specific tables exist (data tables)
        foreach ($ep in $config.Endpoints) {
            if ($ep.TargetTable) {
                $epParts = $ep.TargetTable.Split('.', 2)
                $epSchema = if ($epParts.Count -eq 2) { $epParts[0] } else { 'dbo' }
                $epTable = if ($epParts.Count -eq 2) { $epParts[1] } else { $ep.TargetTable }
                if (-not $createdTables[$ep.TargetTable]) {
                    Ensure-SqlTable -Connection $sqlConnection -SchemaName $epSchema -TableName $epTable -TableSchema $ep.TableSchema
                    $createdTables[$ep.TargetTable] = $true
                }
            }
        }
        
        Write-Log "SQL: Ready -> Default: [$defaultSchema].[$defaultTable], Endpoint tables: $($createdTables.Count)" -Level SUCCESS
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
                } elseif ($response.Content -is [PSCustomObject]) {
                    # Check if response has numbered keys ("1", "2", "3"...)
                    $numericProps = $response.Content.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                    if ($numericProps -and $numericProps.Count -gt 0) {
                        $itemCount = $numericProps.Count
                    } else {
                        $itemCount = 1
                    }
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

            # Always write to log table (WpmsApiResults)
            $logParts = $defaultSqlTable.Split('.', 2)
            $logSchema = if ($logParts.Count -eq 2) { $logParts[0] } else { 'dbo' }
            $logTable = if ($logParts.Count -eq 2) { $logParts[1] } else { $defaultSqlTable }

            Write-SqlResult `
                -Connection $sqlConnection `
                -SchemaName $logSchema `
                -TableName $logTable `
                -EndpointName $endpoint.Name `
                -FullUri $fullUri `
                -RetrievedAt $retrievedAt `
                -StatusCode $statusCode `
                -Success $successFlag `
                -ItemCount $itemCount `
                -Payload $payloadForSql

            Write-Log "  SQL log write: OK -> [$logSchema].[$logTable]" -Level SUCCESS

            # Write parsed data to target table if endpoint has TargetTable
            if ($endpoint.TargetTable -and $successFlag -and $response.Content) {
                $targetParts = $endpoint.TargetTable.Split('.', 2)
                $targetSchema = if ($targetParts.Count -eq 2) { $targetParts[0] } else { 'dbo' }
                $targetTableName = if ($targetParts.Count -eq 2) { $targetParts[1] } else { $endpoint.TargetTable }

                # Handle different response formats:
                # 1. Array of objects: [{"field":"value"}, {"field":"value"}]
                # 2. Single object: {"field":"value"}
                # 3. Object with numbered keys: {"1":{"field":"value"}, "2":{"field":"value"}}
                $dataRows = @()
                if ($response.Content -is [array]) {
                    $dataRows = $response.Content
                } elseif ($response.Content -is [PSCustomObject]) {
                    # Check if all properties are numeric keys (format #3)
                    $props = $response.Content.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
                    if ($props -and $props.Count -gt 0) {
                        # Extract values from numbered keys
                        $dataRows = @($props | ForEach-Object { $_.Value })
                    } else {
                        # Single object (format #2)
                        $dataRows = @($response.Content)
                    }
                } else {
                    $dataRows = @($response.Content)
                }
                
                if ($endpoint.FieldMappings -and $endpoint.TableSchema) {
                    # Use dynamic endpoint data writer
                    Write-EndpointData `
                        -Connection $sqlConnection `
                        -SchemaName $targetSchema `
                        -TableName $targetTableName `
                        -DataRows $dataRows `
                        -RetrievedAt $retrievedAt `
                        -FieldMappings $endpoint.FieldMappings `
                        -TableSchema $endpoint.TableSchema
                } else {
                    # Fallback to legacy TM_USERS writer
                    Write-TmUsersData `
                        -Connection $sqlConnection `
                        -SchemaName $targetSchema `
                        -TableName $targetTableName `
                        -DataRows $dataRows `
                        -RetrievedAt $retrievedAt
                }

                Write-Log "  SQL data write: OK -> [$targetSchema].[$targetTableName] ($($dataRows.Count) rows)" -Level SUCCESS
            }
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
