#!/usr/bin/env powershell
<#
.SYNOPSIS
    Validates the WPMS API Integration installation
.DESCRIPTION
    Checks prerequisites, configuration files, and connectivity to verify proper installation
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = $PSScriptRoot
)

$ErrorActionPreference = "Continue"

Write-Host "=== WPMS API Integration - Installation Validator ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Path: $InstallPath" -ForegroundColor White
Write-Host ""

$issues = 0
$warnings = 0

# Check 1: PowerShell Version
Write-Host "[1/10] Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "  OK PowerShell $($psVersion.Major).$($psVersion.Minor) detected" -ForegroundColor Green
} else {
    Write-Host "  ERROR PowerShell 5.1+ required, found $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Red
    $issues++
}

# Check 2: Required Files
Write-Host ""
Write-Host "[2/10] Checking required files..." -ForegroundColor Yellow
$requiredFiles = @(
    "src\Run-WpmsApiIntegration.ps1",
    "src\Get-AuthToken.ps1",
    "src\RestClient.ps1",
    "config\api-config.psd1",
    "config\Setup-SecurePassword.ps1"
)

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $InstallPath $file
    if (Test-Path $fullPath) {
        Write-Host "  OK $file" -ForegroundColor Green
    } else {
        Write-Host "  ERROR Missing: $file" -ForegroundColor Red
        $issues++
    }
}

# Check 3: Endpoint Configurations
Write-Host ""
Write-Host "[3/10] Checking endpoint configurations..." -ForegroundColor Yellow
$endpointPath = Join-Path $InstallPath "config\endpoints"
if (Test-Path $endpointPath) {
    $endpointFiles = Get-ChildItem -Path $endpointPath -Filter "*.psd1"
    if ($endpointFiles.Count -gt 0) {
        Write-Host "  OK Found $($endpointFiles.Count) endpoint configuration(s)" -ForegroundColor Green
        foreach ($ep in $endpointFiles) {
            Write-Host "    - $($ep.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ERROR No endpoint configurations found" -ForegroundColor Red
        $issues++
    }
} else {
    Write-Host "  ERROR Endpoints directory not found" -ForegroundColor Red
    $issues++
}

# Check 4: Logs Directory
Write-Host ""
Write-Host "[4/10] Checking logs directory..." -ForegroundColor Yellow
$logsPath = Join-Path $InstallPath "logs"
if (Test-Path $logsPath) {
    Write-Host "  OK Logs directory exists" -ForegroundColor Green
} else {
    Write-Host "  WARNING Logs directory not found (will be created automatically)" -ForegroundColor Yellow
    $warnings++
}

# Check 5: Configuration File Validity
Write-Host ""
Write-Host "[5/10] Validating configuration file..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "config\api-config.psd1"
try {
    $config = Import-PowerShellDataFile -Path $configPath
    
    if ($config.Server) {
        Write-Host "  OK API Server: $($config.Server)" -ForegroundColor Green
    } else {
        Write-Host "  ERROR Server not configured" -ForegroundColor Red
        $issues++
    }
    
    if ($config.Credentials -and $config.Credentials.Username) {
        Write-Host "  OK Username: $($config.Credentials.Username)" -ForegroundColor Green
    } else {
        Write-Host "  ERROR Username not configured" -ForegroundColor Red
        $issues++
    }
    
    if ($config.SqlConnectionString) {
        Write-Host "  OK SQL connection string configured" -ForegroundColor Green
    } else {
        Write-Host "  WARNING SQL connection string not configured" -ForegroundColor Yellow
        $warnings++
    }
    
} catch {
    Write-Host "  ERROR Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    $issues++
}

# Check 6: Secure Password File
Write-Host ""
Write-Host "[6/10] Checking encrypted password..." -ForegroundColor Yellow
$securePasswordPath = Join-Path $InstallPath "config\secure-password.txt"
if (Test-Path $securePasswordPath) {
    Write-Host "  OK Encrypted password file exists" -ForegroundColor Green
    try {
        $encryptedPassword = Get-Content -Path $securePasswordPath | ConvertTo-SecureString
        Write-Host "  OK Password can be decrypted by current user" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR Cannot decrypt password (created by different user?)" -ForegroundColor Red
        $issues++
    }
} else {
    Write-Host "  WARNING Encrypted password file not found" -ForegroundColor Yellow
    Write-Host "    Run: .\config\Setup-SecurePassword.ps1" -ForegroundColor Gray
    $warnings++
}

# Check 7: Network Connectivity to API
Write-Host ""
Write-Host "[7/10] Testing API server connectivity..." -ForegroundColor Yellow
try {
    $apiServer = $config.Server -replace "^https?://", ""
    $testConnection = Test-NetConnection -ComputerName $apiServer -Port 80 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($testConnection.TcpTestSucceeded) {
        Write-Host "  OK Can reach API server: $apiServer" -ForegroundColor Green
    } else {
        Write-Host "  ERROR Cannot reach API server: $apiServer" -ForegroundColor Red
        $issues++
    }
} catch {
    Write-Host "  WARNING Could not test connectivity: $($_.Exception.Message)" -ForegroundColor Yellow
    $warnings++
}

# Check 8: SQL Server Connectivity
Write-Host ""
Write-Host "[8/10] Testing SQL Server connectivity..." -ForegroundColor Yellow
if ($config.SqlConnectionString) {
    try {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $config.SqlConnectionString
        $sqlConnection.Open()
        Write-Host "  OK SQL Server connection successful" -ForegroundColor Green
        Write-Host "    Database: $($sqlConnection.Database)" -ForegroundColor Gray
        Write-Host "    Server: $($sqlConnection.DataSource)" -ForegroundColor Gray
        $sqlConnection.Close()
    } catch {
        Write-Host "  ERROR SQL connection failed: $($_.Exception.Message)" -ForegroundColor Red
        $issues++
    }
} else {
    Write-Host "  WARNING Skipping (no connection string configured)" -ForegroundColor Yellow
}

# Check 9: Execution Policy
Write-Host ""
Write-Host "[9/10] Checking PowerShell execution policy..." -ForegroundColor Yellow
$execPolicy = Get-ExecutionPolicy
if ($execPolicy -eq "Restricted") {
    Write-Host "  ERROR Execution Policy: $execPolicy (too restrictive)" -ForegroundColor Red
    Write-Host "    Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
    $issues++
} else {
    Write-Host "  OK Execution Policy: $execPolicy" -ForegroundColor Green
}

# Check 10: .NET Framework
Write-Host ""
Write-Host "[10/10] Checking .NET Framework..." -ForegroundColor Yellow
$dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
Write-Host "  OK $dotnetVersion" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($issues -eq 0 -and $warnings -eq 0) {
    Write-Host "SUCCESS: ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation is ready to use!" -ForegroundColor White
    Write-Host "Run: .\src\Run-WpmsApiIntegration.ps1 -Verbose" -ForegroundColor Gray
} elseif ($issues -eq 0) {
    Write-Host "SUCCESS: Installation validated with $warnings warning(s)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Installation is functional but may need configuration." -ForegroundColor White
} else {
    Write-Host "FAILED: Found $issues issue(s) and $warnings warning(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please resolve the issues above before running the integration." -ForegroundColor White
}

Write-Host ""

# Return exit code
exit $issues
