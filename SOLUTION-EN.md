# WPMS API Integration Solution - Technical Documentation

## Overview

Automated integration system between WPMS API and SQL Server for synchronization of productivity and human resources data.

## Solution Architecture

### Main Components

1. **Run-WpmsApiIntegration.ps1** - Main production script
   - Executes API calls for multiple endpoints
   - Implements automatic day-by-day import for productivity data
   - Writes results to SQL Server tables
   - Generates detailed execution logs

2. **Import-HistoricalData.ps1** - Historical data import script
   - Imports data from specific date ranges
   - Automatically calculates start date from last database record
   - Supports dry-run mode for validation
   - Uses MERGE operations to avoid duplicates

3. **Get-AuthToken.ps1** - Authentication module
   - Bearer token management for API
   - Support for encrypted credentials

4. **RestClient.ps1** - Generic HTTP client
   - Wrapper for REST API calls
   - Error handling and timeouts
   - Support for complex query parameters

### Directory Structure

```
EVERestAPI_VS/
├── src/                              # Main scripts
│   ├── Run-WpmsApiIntegration.ps1    # Production script
│   ├── Import-HistoricalData.ps1     # Historical import
│   ├── Get-AuthToken.ps1             # Authentication
│   └── RestClient.ps1                # REST client
├── config/                           # Configuration
│   ├── api-config.psd1               # Main configuration
│   ├── Setup-SecurePassword.ps1      # Password encryption
│   ├── secure-password.txt           # Encrypted password (DPAPI)
│   └── endpoints/                    # Endpoint configurations
│       ├── TM_USERS.psd1
│       ├── TM_UDT.psd1
│       ├── TM_EQUIPA.psd1
│       └── MOV_ESTAT_PRODUTIVIDADE.psd1
├── logs/                             # Execution logs
├── tests/                            # Test scripts
└── Deploy-ToServer.ps1               # Deployment script
```

## Key Features

### 1. Automatic Day-by-Day Import

The main script implements intelligent import logic:

```powershell
# Detects last record in database
SELECT MAX([Date]) FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]

# Starts import from the next day
# Iterates day-by-day until today
# Writes each day individually
```

**Benefits:**
- No duplicates (uses MERGE statements)
- Automatic incremental import
- Continuity after failures
- Daily data granularity

### 2. Credential Security

Implements Windows DPAPI (Data Protection API) encryption:

```powershell
# Encrypt password
.\config\Setup-SecurePassword.ps1

# Password is encrypted for:
# - Specific user
# - Specific machine
# Cannot be decrypted in another context
```

### 3. Configurable Endpoints

Each endpoint has its own configuration in .psd1 file:

```powershell
@{
    Name = "Endpoint Name"
    Uri = "/Eve/api/WebService/EndpointName"
    Method = "GET"
    Parameters = @{
        DTVL = @{ val1 = "20250101" }
        ENTI = @{ val1 = "('92','93')"; sig1 = "IN" }
    }
    TargetTable = "dbo.TargetTable"
    FieldMappings = @{ ... }
    TableSchema = @{ ... }
}
```

### 4. Data Type Mapping

Automatic type conversion API → SQL:

| SQL Type | PowerShell Type | Handling |
|----------|-----------------|----------|
| DATE | DateTime | ParseExact with yyyyMMdd format |
| DECIMAL(18,3) | Decimal | Conversion with validation |
| INT | Int32 | Conversion with validation |
| NVARCHAR | String | No conversion |

### 5. Logging System

Structured logs with levels:

```
[2025-12-06 12:41:32] [INFO] Starting API calls...
[2025-12-06 12:41:33] [SUCCESS] Status: SUCCESS (HTTP 200)
[2025-12-06 12:41:33] [ERROR] SQL write failed: ...
[2025-12-06 12:41:34] [WARNING] API returned no data
```

**Levels:** INFO, SUCCESS, WARNING, ERROR

## Implemented Endpoints

### 1. TM_USERS - Users
- **Endpoint:** I0002read_I0002V03
- **Table:** dbo.TM_USERS
- **Description:** Complete list of system users
- **Fields:** 15 fields including Operator, Name, Profile, Email, etc.

### 2. TM_UDT - Work Types
- **Endpoint:** D0276Dread_all
- **Table:** dbo.TM_UDT
- **Description:** Available work/task types
- **Fields:** WrkType, Name, Description, GrpCode

### 3. TM_EQUIPA - Teams
- **Endpoint:** D0256Dread_all
- **Table:** dbo.TM_EQUIPA
- **Description:** Work team structure
- **Fields:** Team, Name, Squadra, Director

### 4. MOV_ESTAT_PRODUTIVIDADE - Productivity
- **Endpoint:** FAPLOGR011showStatsErrors
- **Table:** dbo.MOV_ESTAT_PRODUTIVIDADE
- **Description:** Daily productivity statistics
- **Fields:** 26 fields including quantities, times, distances, errors
- **Import:** Automatic day-by-day

## Server Deployment

### Prerequisites

1. **Windows Server** with PowerShell 5.1+
2. **SQL Server** accessible via Windows Authentication
3. **Connectivity** to wpms.prodout.com
4. **Permissions:**
   - Read/write access to installation directory
   - Access to EVEReporting database
   - Create Scheduled Tasks (optional)

### Deployment Process

```powershell
# 1. Clone or copy repository
git clone https://github.com/pduarte74/EVERestAPI_VS.git

# 2. Run deployment script
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsIntegration" -SetupScheduledTask

# 3. Configure password (on server)
cd C:\Apps\WpmsIntegration\config
.\Setup-SecurePassword.ps1

# 4. Verify configuration
notepad C:\Apps\WpmsIntegration\config\api-config.psd1

# 5. Test execution
cd C:\Apps\WpmsIntegration\src
.\Run-WpmsApiIntegration.ps1 -Verbose
```

### Schedule Configuration

The scheduled task runs daily at 06:00 AM by default.

**Modify schedule:**
1. Open Task Scheduler
2. Locate "WPMS-API-Integration"
3. Properties → Triggers → Edit
4. Adjust time/frequency

**Run under service account:**
```powershell
# In Task Scheduler:
# General → "Run whether user is logged on or not"
# General → Configure service account
# IMPORTANT: Recreate secure-password.txt with service account
```

## Historical Data Import

### Basic Usage

```powershell
# Import full month
.\Import-HistoricalData.ps1 -StartDate 20250801 -EndDate 20250831

# Import from specific date to today
.\Import-HistoricalData.ps1 -StartDate 20250101

# Continue automatically from last record
.\Import-HistoricalData.ps1

# Dry-run mode (no writes)
.\Import-HistoricalData.ps1 -StartDate 20250101 -DryRun
```

### Start Date Logic

When `-StartDate` is not provided:

1. Queries: `SELECT MAX([Date]) FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]`
2. If data exists: Starts from next day
3. If table empty: Starts from today

### Safe Re-import

The script uses `MERGE` statements for upsert operations:

```sql
MERGE INTO [dbo].[MOV_ESTAT_PRODUTIVIDADE] AS target
USING (SELECT ...) AS source
ON target.[Date] = source.[Date] 
   AND target.[Whrs] = source.[Whrs]
   AND target.[Oprt] = source.[Oprt]
   AND target.[WrkType] = source.[WrkType]
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...
```

**Benefits:**
- No duplicate key errors
- Updates existing records
- Inserts new records
- Atomic operation

## Monitoring and Troubleshooting

### Logs

Location: `logs\wpms-api-YYYYMMDD-HHMMSS.log`

```powershell
# View latest log
Get-ChildItem .\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Search for errors
Get-Content .\logs\*.log | Select-String "ERROR"

# Check specific endpoint success
Get-Content .\logs\*.log | Select-String "MOV_ESTAT"
```

### Data Verification

```sql
-- Last import
SELECT MAX([Date]) AS LastDate, COUNT(*) AS TotalRecords
FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]

-- Records per day
SELECT [Date], COUNT(*) AS Records
FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]
GROUP BY [Date]
ORDER BY [Date] DESC

-- Check for gaps
WITH DateRange AS (
    SELECT CAST('2025-01-01' AS DATE) AS [Date]
    UNION ALL
    SELECT DATEADD(day, 1, [Date])
    FROM DateRange
    WHERE [Date] < CAST(GETDATE() AS DATE)
)
SELECT dr.[Date]
FROM DateRange dr
LEFT JOIN [dbo].[MOV_ESTAT_PRODUTIVIDADE] m ON dr.[Date] = m.[Date]
WHERE m.[Date] IS NULL
  AND DATEPART(weekday, dr.[Date]) NOT IN (1, 7) -- Exclude weekends
OPTION (MAXRECURSION 0)
```

### Common Errors

#### 1. Authentication Error
```
ERROR: Authentication failed: The remote server returned an error: (401) Unauthorized
```
**Solution:** Recreate secure-password.txt

#### 2. SQL Connection Error
```
ERROR: SQL connection failed: Cannot open database "EVEReporting"
```
**Solution:** Verify connection string and permissions

#### 3. API Timeout
```
ERROR: Error retrieving data: The operation has timed out
```
**Solution:** Temporary API issue, try again

#### 4. API Error 500
```
ERROR: The remote server returned an error: (500) Internal Server Error
```
**Solution:** Temporary WPMS issue, re-run later

## Maintenance

### Log Rotation

```powershell
# Keep only last 30 days
Get-ChildItem .\logs\*.log | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item
```

### Password Update

```powershell
# When API password changes:
cd config
.\Setup-SecurePassword.ps1
# Enter new password when prompted
```

### Configuration Backup

```powershell
# Backup configs (exclude encrypted password)
$backupPath = ".\backup-$(Get-Date -Format 'yyyyMMdd')"
Copy-Item .\config\*.psd1 $backupPath -Recurse
Copy-Item .\config\endpoints\*.psd1 "$backupPath\endpoints"
```

## Performance

### Average Execution Time

| Endpoint | Records | Time |
|----------|---------|------|
| TM_USERS | ~400 | 40s |
| TM_UDT | ~170 | 15s |
| TM_EQUIPA | ~40 | 5s |
| MOV_ESTAT (1 day) | ~50 | 10s |
| MOV_ESTAT (7 days) | ~350 | 60s |

### Optimizations

1. **Bulk Insert:** Uses SqlBulkCopy for large volumes
2. **MERGE Statements:** Efficient upsert operations
3. **Reused Connections:** One SQL connection per execution
4. **Token Caching:** Token valid for 24h

## Security

### Credentials

- ✅ Password encrypted with DPAPI
- ✅ Not versioned in Git (.gitignore)
- ✅ User/machine specific
- ✅ Not portable between environments

### Logs

- ⚠️ Do not contain passwords
- ⚠️ Contain business data (API records)
- ℹ️ Consider regular rotation/cleanup

### SQL Injection

- ✅ Uses SQL command parameterization
- ✅ No string concatenation in queries
- ✅ Data type validation

## Contact and Support

**Repository:** https://github.com/pduarte74/EVERestAPI_VS
**Developer:** Pedro Duarte (pedro.duarte@prodout.com)

## Version History

### v1.3.0 (2025-12-06)
- ✨ Automatic day-by-day import for MOV_ESTAT_PRODUTIVIDADE
- ✨ Automatic calculation of start date from last record
- 🐛 Fixed string parsing errors with colons
- 📝 Complete documentation in PT/EN

### v1.2.0 (2025-12-05)
- ✨ Historical import script with MERGE
- 🔄 Upsert operations to avoid duplicates

### v1.1.0 (2025-12-04)
- ✨ Data type conversion for MOV_ESTAT_PRODUTIVIDADE
- ✨ Support for numbered-key response format

### v1.0.0 (2025-12-03)
- 🎉 Initial release
- ✨ 4 endpoints implemented
- 🔐 DPAPI password encryption
- 📦 Complete deployment package
