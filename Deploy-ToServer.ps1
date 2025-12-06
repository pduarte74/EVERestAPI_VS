#!/usr/bin/env powershell
<#
.SYNOPSIS
    Deployment script for WPMS API Integration on a server
.DESCRIPTION
    This script prepares and deploys the WPMS API integration to a target server.
    It validates prerequisites, copies files, and sets up the environment.
.PARAMETER TargetPath
    Destination path on the server where files will be deployed
.PARAMETER ServerName
    Name of the target server (for remote deployment)
.PARAMETER SetupScheduledTask
    Create a Windows Scheduled Task to run the integration automatically
.PARAMETER TaskSchedule
    Schedule for the task: Daily, Hourly, or Custom (default: Daily at 6:00 AM)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupScheduledTask,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Daily", "Hourly", "Custom")]
    [string]$TaskSchedule = "Daily"
)

$ErrorActionPreference = "Stop"

Write-Host "=== WPMS API Integration - Server Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Validate source files
$sourcePath = $PSScriptRoot
$requiredFiles = @(
    "src\Run-WpmsApiIntegration.ps1",
    "src\Get-AuthToken.ps1",
    "src\RestClient.ps1",
    "config\api-config.psd1",
    "config\Setup-SecurePassword.ps1",
    "config\README.md"
)

$requiredDirs = @(
    "config\endpoints"
)

Write-Host "[1/6] Validating source files..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $sourcePath $file
    if (-not (Test-Path $fullPath)) {
        Write-Host "ERROR: Required file not found: $file" -ForegroundColor Red
        exit 1
    }
}

foreach ($dir in $requiredDirs) {
    $fullPath = Join-Path $sourcePath $dir
    if (-not (Test-Path $fullPath)) {
        Write-Host "ERROR: Required directory not found: $dir" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  Source files validated successfully" -ForegroundColor Green

# Determine if this is a local or remote deployment
$isRemote = -not [string]::IsNullOrEmpty($ServerName)

if ($isRemote) {
    Write-Host ""
    Write-Host "[2/6] Testing remote connection to $ServerName..." -ForegroundColor Yellow
    try {
        $testConnection = Test-Connection -ComputerName $ServerName -Count 1 -Quiet
        if (-not $testConnection) {
            Write-Host "ERROR: Cannot reach server $ServerName" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Remote connection successful" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    # Convert to UNC path for remote deployment
    if ($TargetPath -match "^[A-Z]:") {
        $driveLetter = $TargetPath.Substring(0, 1)
        $pathWithoutDrive = $TargetPath.Substring(2)
        $TargetPath = "\\$ServerName\$driveLetter`$$pathWithoutDrive"
    }
} else {
    Write-Host ""
    Write-Host "[2/6] Local deployment to $TargetPath" -ForegroundColor Yellow
}

# Create target directory structure
Write-Host ""
Write-Host "[3/6] Creating target directory structure..." -ForegroundColor Yellow
try {
    $dirsToCreate = @(
        $TargetPath,
        (Join-Path $TargetPath "src"),
        (Join-Path $TargetPath "config"),
        (Join-Path $TargetPath "config\endpoints"),
        (Join-Path $TargetPath "logs"),
        (Join-Path $TargetPath "tests")
    )
    
    foreach ($dir in $dirsToCreate) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Host "  Created: $dir" -ForegroundColor Gray
        }
    }
    Write-Host "  Directory structure created" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create directories: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Copy files
Write-Host ""
Write-Host "[4/6] Copying files..." -ForegroundColor Yellow
try {
    # Copy source files
    Copy-Item -Path (Join-Path $sourcePath "src\*.ps1") -Destination (Join-Path $TargetPath "src") -Force
    Write-Host "  Copied: src\*.ps1" -ForegroundColor Gray
    
    # Copy test files
    if (Test-Path (Join-Path $sourcePath "tests\*.ps1")) {
        Copy-Item -Path (Join-Path $sourcePath "tests\*.ps1") -Destination (Join-Path $TargetPath "tests") -Force
        Write-Host "  Copied: tests\*.ps1" -ForegroundColor Gray
    }
    
    # Copy config files (excluding secure-password.txt)
    Copy-Item -Path (Join-Path $sourcePath "config\*.psd1") -Destination (Join-Path $TargetPath "config") -Force
    Copy-Item -Path (Join-Path $sourcePath "config\*.ps1") -Destination (Join-Path $TargetPath "config") -Force
    Copy-Item -Path (Join-Path $sourcePath "config\*.md") -Destination (Join-Path $TargetPath "config") -Force
    Write-Host "  Copied: config files" -ForegroundColor Gray
    
    # Copy endpoint configs
    Copy-Item -Path (Join-Path $sourcePath "config\endpoints\*.psd1") -Destination (Join-Path $TargetPath "config\endpoints") -Force
    Write-Host "  Copied: endpoint configurations" -ForegroundColor Gray
    
    # Copy README if exists
    if (Test-Path (Join-Path $sourcePath "README.md")) {
        Copy-Item -Path (Join-Path $sourcePath "README.md") -Destination $TargetPath -Force
        Write-Host "  Copied: README.md" -ForegroundColor Gray
    }
    
    # Copy solution documentation
    if (Test-Path (Join-Path $sourcePath "SOLUTION-PT.md")) {
        Copy-Item -Path (Join-Path $sourcePath "SOLUTION-PT.md") -Destination $TargetPath -Force
        Write-Host "  Copied: SOLUTION-PT.md" -ForegroundColor Gray
    }
    if (Test-Path (Join-Path $sourcePath "SOLUTION-EN.md")) {
        Copy-Item -Path (Join-Path $sourcePath "SOLUTION-EN.md") -Destination $TargetPath -Force
        Write-Host "  Copied: SOLUTION-EN.md" -ForegroundColor Gray
    }
    
    # Copy deployment documentation
    if (Test-Path (Join-Path $sourcePath "DEPLOYMENT.md")) {
        Copy-Item -Path (Join-Path $sourcePath "DEPLOYMENT.md") -Destination $TargetPath -Force
        Write-Host "  Copied: DEPLOYMENT.md" -ForegroundColor Gray
    }
    if (Test-Path (Join-Path $sourcePath "Deploy-ToServer.ps1")) {
        Copy-Item -Path (Join-Path $sourcePath "Deploy-ToServer.ps1") -Destination $TargetPath -Force
        Write-Host "  Copied: Deploy-ToServer.ps1" -ForegroundColor Gray
    }
    if (Test-Path (Join-Path $sourcePath "Verify-Installation.ps1")) {
        Copy-Item -Path (Join-Path $sourcePath "Verify-Installation.ps1") -Destination $TargetPath -Force
        Write-Host "  Copied: Verify-Installation.ps1" -ForegroundColor Gray
    }
    
    Write-Host "  All files copied successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to copy files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Post-deployment setup instructions
Write-Host ""
Write-Host "[5/6] Post-deployment setup required..." -ForegroundColor Yellow
Write-Host "  The following manual steps are required on the server:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Configure encrypted password:" -ForegroundColor Cyan
if ($isRemote) {
    Write-Host "     - RDP/Login to: $ServerName" -ForegroundColor Gray
}
Write-Host "     - Run: $TargetPath\config\Setup-SecurePassword.ps1" -ForegroundColor Gray
Write-Host "     - Enter the API password when prompted" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Verify SQL Server connectivity:" -ForegroundColor Cyan
Write-Host "     - Check connection string in: $TargetPath\config\api-config.psd1" -ForegroundColor Gray
Write-Host "     - Ensure Windows Authentication has access to EVEReporting database" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Test the integration:" -ForegroundColor Cyan
Write-Host "     - Run: $TargetPath\src\Run-WpmsApiIntegration.ps1 -Verbose" -ForegroundColor Gray
Write-Host ""

# Setup Scheduled Task
if ($SetupScheduledTask) {
    Write-Host ""
    Write-Host "[6/6] Creating Scheduled Task..." -ForegroundColor Yellow
    
    if ($isRemote) {
        Write-Host "  Remote scheduled task creation not yet implemented" -ForegroundColor Yellow
        Write-Host "  Please create the task manually on $ServerName using Task Scheduler" -ForegroundColor Yellow
    } else {
        try {
            $taskName = "WPMS-API-Integration"
            $scriptPath = Join-Path $TargetPath "src\Run-WpmsApiIntegration.ps1"
            
            # Check if task already exists
            $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existingTask) {
                Write-Host "  Task '$taskName' already exists. Removing..." -ForegroundColor Yellow
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
            
            # Create action
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            
            # Create trigger based on schedule
            switch ($TaskSchedule) {
                "Daily" {
                    $trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
                }
                "Hourly" {
                    $trigger = New-ScheduledTaskTrigger -Once -At "00:00" -RepetitionInterval (New-TimeSpan -Hours 1)
                }
                "Custom" {
                    Write-Host "  Custom schedule selected. Creating daily trigger at 06:00 AM" -ForegroundColor Gray
                    Write-Host "  Please modify the task schedule manually in Task Scheduler" -ForegroundColor Gray
                    $trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
                }
            }
            
            # Create settings
            $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
            
            # Register task (runs as current user)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "WPMS API Integration - Automated data sync" | Out-Null
            
            Write-Host "  Scheduled Task created successfully" -ForegroundColor Green
            Write-Host "  Task Name: $taskName" -ForegroundColor Gray
            Write-Host "  Schedule: $TaskSchedule" -ForegroundColor Gray
            Write-Host "  Next Run: $((Get-ScheduledTask -TaskName $taskName).Triggers[0].StartBoundary)" -ForegroundColor Gray
        } catch {
            Write-Host "ERROR: Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  You can create the task manually using Task Scheduler" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "[6/6] Skipping Scheduled Task setup" -ForegroundColor Yellow
    Write-Host "  To create a scheduled task later, run with -SetupScheduledTask parameter" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Path: $TargetPath" -ForegroundColor White
if ($isRemote) {
    Write-Host "Server: $ServerName" -ForegroundColor White
}
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Complete the post-deployment setup steps above" -ForegroundColor White
Write-Host "  2. Test the integration manually" -ForegroundColor White
Write-Host "  3. Monitor logs in: $TargetPath\logs\" -ForegroundColor White
Write-Host ""
