# WPMS API Integration - Deployment Guide

## Overview
This package provides automated integration between WPMS API and SQL Server for data synchronization.

## Prerequisites

### Server Requirements
- **Operating System**: Windows Server 2012 R2 or later
- **PowerShell**: Version 5.1 or later
- **.NET Framework**: 4.7.2 or later
- **Network Access**: 
  - HTTP access to `wpms.prodout.com`
  - SQL Server access to `sql-os-prd-01.rede.local`

### Permissions Required
- **SQL Server**: Windows Authentication with read/write access to `EVEReporting` database
- **File System**: Read/write access to deployment directory
- **Scheduled Tasks**: Permission to create/modify scheduled tasks (optional)

## Deployment Methods

### Method 1: Automated Deployment (Recommended)

```powershell
# Local deployment
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration"

# With Scheduled Task
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration" -SetupScheduledTask -TaskSchedule Daily

# Remote deployment (requires network access)
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration" -ServerName "SERVER01"
```

### Method 2: Manual Deployment

1. **Copy Files**: Copy the entire package to the target server
   ```
   C:\Apps\WpmsApiIntegration\
   ├── src\
   │   ├── Run-WpmsApiIntegration.ps1
   │   ├── Get-AuthToken.ps1
   │   └── RestClient.ps1
   ├── config\
   │   ├── api-config.psd1
   │   ├── Setup-SecurePassword.ps1
   │   ├── README.md
   │   └── endpoints\
   │       ├── TM_USERS.psd1
   │       ├── TM_UDT.psd1
   │       ├── TM_EQUIPA.psd1
   │       └── MOV_ESTAT_PRODUTIVIDADE.psd1
   └── logs\
   ```

2. **Create Directories**: Ensure `logs\` directory exists

## Post-Deployment Configuration

### 1. Configure Encrypted Password

On the target server, run:
```powershell
cd C:\Apps\WpmsApiIntegration
.\config\Setup-SecurePassword.ps1
```

Enter the API password when prompted. The password will be encrypted and saved to `config\secure-password.txt`.

⚠️ **Important**: This must be done by the Windows account that will run the integration.

### 2. Verify Configuration

Edit `config\api-config.psd1` if needed:
- Check SQL Server connection string
- Verify API server URL
- Confirm username is correct

### 3. Test the Integration

Run manually to verify everything works:
```powershell
cd C:\Apps\WpmsApiIntegration
.\src\Run-WpmsApiIntegration.ps1 -Verbose
```

Check for:
- ✅ Authentication successful
- ✅ SQL connection successful
- ✅ Data retrieved from all endpoints
- ✅ Records inserted into database

Review logs in `logs\` directory.

### 4. Setup Scheduled Execution (Optional)

#### Option A: Using Deployment Script
```powershell
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration" -SetupScheduledTask -TaskSchedule Daily
```

#### Option B: Using Task Scheduler (Manual)

1. Open **Task Scheduler** (`taskschd.msc`)
2. Create New Task:
   - **Name**: WPMS-API-Integration
   - **User**: Service account or appropriate user
   - **Run whether user is logged on or not**: Checked
   - **Run with highest privileges**: Checked

3. **Trigger**: Set schedule (e.g., Daily at 6:00 AM)

4. **Action**: Start a program
   - **Program**: `powershell.exe`
   - **Arguments**: 
     ```
     -NoProfile -ExecutionPolicy Bypass -File "C:\Apps\WpmsApiIntegration\src\Run-WpmsApiIntegration.ps1"
     ```
   - **Start in**: `C:\Apps\WpmsApiIntegration`

5. **Settings**:
   - ✅ Allow task to be run on demand
   - ✅ Run task as soon as possible after scheduled start is missed
   - ✅ If the task fails, restart every: 15 minutes

## Configuration Files

### API Configuration (`config\api-config.psd1`)
```powershell
@{
    Server = "http://wpms.prodout.com"
    
    Credentials = @{
        Username = "your-username"
        SecurePasswordFile = "secure-password.txt"
    }
    
    SqlConnectionString = "Server=sql-server;Database=EVEReporting;Integrated Security=True;Encrypt=False;"
    SqlTable = "dbo.WpmsApiResults"
    
    EndpointConfigFiles = @(
        "endpoints\TM_USERS.psd1"
        "endpoints\TM_UDT.psd1"
        "endpoints\TM_EQUIPA.psd1"
        "endpoints\MOV_ESTAT_PRODUTIVIDADE.psd1"
    )
}
```

### Endpoint Configurations
Each endpoint has its own `.psd1` file in `config\endpoints\` with:
- API URI and method
- Parameters
- Target SQL table
- Field mappings
- Data schema

## Monitoring & Maintenance

### Log Files
- Location: `C:\Apps\WpmsApiIntegration\logs\`
- Format: `wpms-api-YYYYMMDD-HHMMSS.log`
- Retention: Manual cleanup recommended

### Log Levels
- `[INFO]`: Normal operations
- `[SUCCESS]`: Successful operations
- `[WARNING]`: Non-critical issues
- `[ERROR]`: Failures requiring attention

### Health Checks
```powershell
# View recent logs
Get-Content "C:\Apps\WpmsApiIntegration\logs\wpms-api-*.log" -Tail 50

# Check SQL data
# Connect to SQL Server and verify recent RetrievedAt timestamps

# Test connection manually
.\src\Run-WpmsApiIntegration.ps1 -Verbose
```

### Common Issues

**Issue**: "Secure password file not found"
- **Solution**: Run `.\config\Setup-SecurePassword.ps1` as the service account

**Issue**: "Failed to decrypt password"
- **Solution**: Password was encrypted by different user - recreate with correct account

**Issue**: "SQL connection failed"
- **Solution**: Verify Windows Authentication has database access

**Issue**: "Cannot reach API server"
- **Solution**: Check network connectivity and firewall rules

## Security Considerations

1. **Password Encryption**: Uses Windows DPAPI - encrypted per user/machine
2. **SQL Authentication**: Uses Windows Integrated Security
3. **Log Files**: May contain sensitive data - restrict access appropriately
4. **Network**: API calls use HTTP - ensure network security

## Updating the Integration

To deploy updates:
```powershell
# Pull latest changes from repository
git pull

# Redeploy to server
.\Deploy-ToServer.ps1 -TargetPath "C:\Apps\WpmsApiIntegration" -ServerName "YOUR-SERVER"

# Encrypted password file is preserved (not overwritten)
```

## Rollback Procedure

1. Stop the scheduled task
2. Restore previous version files
3. Restart the scheduled task
4. Verify with manual test run

## Support & Troubleshooting

For issues:
1. Check logs in `logs\` directory
2. Run with `-Verbose` flag for detailed output
3. Verify configuration files
4. Test SQL connectivity separately
5. Confirm API credentials are correct

## Backup Recommendations

Backup the following:
- `config\api-config.psd1`
- `config\endpoints\*.psd1`
- `config\secure-password.txt` (keep secure!)
- Scheduled Task configuration

**Note**: The encrypted password file cannot be restored to a different machine/user.
