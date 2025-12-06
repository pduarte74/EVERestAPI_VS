#!/usr/bin/env powershell

# Delete last 5 days from MOV_ESTAT_PRODUTIVIDADE and test main script

Write-Host "=== Deleting last 5 days from MOV_ESTAT_PRODUTIVIDADE ===" -ForegroundColor Cyan
Write-Host ""

$connString = "Server=sql-os-prd-01.rede.local;Database=EVEReporting;Integrated Security=True;Encrypt=False;"

try {
    $conn = New-Object System.Data.SqlClient.SqlConnection $connString
    $conn.Open()
    Write-Host "Connected to database" -ForegroundColor Green
    
    # Get current max date
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT MAX([Date]) AS MaxDate, COUNT(*) AS TotalRows FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]"
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $maxDate = $reader['MaxDate']
        $totalRows = $reader['TotalRows']
        $reader.Close()
        
        Write-Host "Before deletion:" -ForegroundColor White
        Write-Host "  Max date: $maxDate" -ForegroundColor Cyan
        Write-Host "  Total rows: $totalRows" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Delete last 5 days (from 5 days ago to today)
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "DELETE FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE] WHERE [Date] >= DATEADD(day, -4, CAST(GETDATE() AS DATE))"
    $deleted = $cmd.ExecuteNonQuery()
    Write-Host "Deleted $deleted rows" -ForegroundColor Yellow
    Write-Host ""
    
    # Check new max date
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT MAX([Date]) AS MaxDate, COUNT(*) AS TotalRows FROM [dbo].[MOV_ESTAT_PRODUTIVIDADE]"
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $newMaxDate = $reader['MaxDate']
        $newTotalRows = $reader['TotalRows']
        $reader.Close()
        
        Write-Host "After deletion:" -ForegroundColor White
        Write-Host "  New max date: $newMaxDate" -ForegroundColor Green
        Write-Host "  Remaining rows: $newTotalRows" -ForegroundColor Green
    }
    
    $conn.Close()
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Running main integration script ===" -ForegroundColor Cyan
Write-Host ""

# Run main script
cd "$PSScriptRoot\..\src"
& .\Run-WpmsApiIntegration.ps1

Write-Host ""
Write-Host "=== Test completed ===" -ForegroundColor Green
