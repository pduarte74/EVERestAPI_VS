# WPMS API Integration

Automated integration system for synchronizing data between WPMS API and SQL Server.

## Features

- ✅ Automated API data retrieval from WPMS
- ✅ SQL Server integration with automatic table creation
- ✅ Secure password encryption using Windows DPAPI
- ✅ Multiple endpoint support with individual configurations
- ✅ Dynamic parameter calculation (e.g., date ranges)
- ✅ Comprehensive logging
- ✅ Type-safe data conversion (DATE, DECIMAL, INT)
- ✅ MERGE operations for upsert functionality

## Quick Start

### 1. Setup Password
```powershell
.\config\Setup-SecurePassword.ps1
```

### 2. Configure Connection
Edit `config\api-config.psd1`:
- Verify SQL Server connection string
- Confirm API server URL

### 3. Run Integration
```powershell
.\src\Run-WpmsApiIntegration.ps1 -Verbose
```

## Project Structure

```
EVERestAPI_VS/
├── src/
│   ├── Run-WpmsApiIntegration.ps1  # Main integration script
│   ├── Get-AuthToken.ps1            # WPMS authentication
│   └── RestClient.ps1               # API client
├── config/
│   ├── api-config.psd1              # Main configuration
│   ├── Setup-SecurePassword.ps1     # Password encryption utility
│   ├── README.md                    # Security documentation
│   └── endpoints/                   # Endpoint configurations
│       ├── TM_USERS.psd1
│       ├── TM_UDT.psd1
│       ├── TM_EQUIPA.psd1
│       └── MOV_ESTAT_PRODUTIVIDADE.psd1
├── logs/                            # Application logs
├── Deploy-ToServer.ps1              # Deployment script
└── DEPLOYMENT.md                    # Deployment guide
```

## Endpoints

| Endpoint | Description | Records | Target Table |
|----------|-------------|---------|--------------|
| TM_USERS | User management | ~406 | dbo.TM_USERS |
| TM_UDT | UDT data | ~166 | dbo.TM_UDT |
| TM_EQUIPA | Team data | ~37 | dbo.TM_EQUIPA |
| MOV_ESTAT_PRODUTIVIDADE | Productivity statistics | ~536 | dbo.MOV_ESTAT_PRODUTIVIDADE |

## Data Types

The integration automatically converts API string data to appropriate SQL types:
- **DATE**: yyyyMMdd format → SQL DATE
- **DECIMAL(18,3)**: Quantities and measurements
- **INT**: Counters and identifiers
- **NVARCHAR**: Text fields

## Configuration

### Main Config (`config\api-config.psd1`)
```powershell
@{
    Server = "http://wpms.prodout.com"
    Credentials = @{
        Username = "your-username"
        SecurePasswordFile = "secure-password.txt"
    }
    SqlConnectionString = "Server=...;Database=EVEReporting;Integrated Security=True;Encrypt=False;"
    EndpointConfigFiles = @(
        "endpoints\TM_USERS.psd1"
        # ... more endpoints
    )
}
```

### Endpoint Config Example
```powershell
@{
    EndpointName = "TM_USERS"
    ApiMethod = "I0002read_I0002V03"
    HttpMethod = "GET"
    TargetTable = "dbo.TM_USERS"
    TableSchema = @{
        Columns = @(
            @{ Name = "Utente"; Type = "NVARCHAR(50)"; PrimaryKey = $true }
            @{ Name = "Utente_nome"; Type = "NVARCHAR(200)" }
            # ... more columns
        )
    }
}
```

## Security

- **Password Encryption**: Windows DPAPI (user+machine specific)
- **SQL Authentication**: Windows Integrated Security
- **Git Ignore**: Encrypted password files excluded from version control

See `config\README.md` for security details.

## Deployment

For production deployment, see [DEPLOYMENT.md](DEPLOYMENT.md).

Quick deployment:
```powershell
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration" -SetupScheduledTask
```

## Monitoring

### Logs
Located in `logs\` directory with format: `wpms-api-YYYYMMDD-HHMMSS.log`

### Log Levels
- `[INFO]`: Informational messages
- `[SUCCESS]`: Successful operations
- `[WARNING]`: Non-critical issues
- `[ERROR]`: Failures

### Example Output
```
[2025-12-05 18:21:39] [SUCCESS] Authentication token obtained successfully
[2025-12-05 18:21:40] [INFO]   Items returned: 406
[2025-12-05 18:22:02] [SUCCESS]   SQL data write: OK -> [dbo].[TM_USERS] (406 rows)
```

## Dynamic Parameters

Supports dynamic token replacement in parameters:

```powershell
Parameters = @{
    DTVL = @{ 
        val1 = "DYNAMIC:PreviousMondayDate"  # Calculates Monday of previous week
        sig1 = "GE" 
    }
}
```

## Requirements

- Windows Server 2012 R2+ or Windows 10+
- PowerShell 5.1+
- .NET Framework 4.7.2+
- Network access to WPMS API server
- SQL Server access with Windows Authentication

## Development

### Testing
```powershell
# Test specific endpoint
.\src\Run-WpmsApiIntegration.ps1 -Verbose

# Check SQL data
# Query EVEReporting database tables
```

### Adding New Endpoints

1. Create endpoint config in `config\endpoints\YourEndpoint.psd1`
2. Add to `EndpointConfigFiles` in `config\api-config.psd1`
3. Test with `-Verbose` flag

## Troubleshooting

**"Secure password file not found"**
```powershell
.\config\Setup-SecurePassword.ps1
```

**SQL Connection Issues**
- Verify Windows Authentication has database access
- Check connection string format
- Test SQL connectivity separately

**API Authentication Failed**
- Verify username and password
- Check network connectivity to WPMS server

## License

Internal use - ProdOut/EVE

## Repository

GitHub: [pduarte74/EVERestAPI_VS](https://github.com/pduarte74/EVERestAPI_VS)
