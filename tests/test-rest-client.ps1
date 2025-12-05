Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\..\src\Get-AuthToken.ps1"
. "$scriptRoot\..\src\RestClient.ps1"

Write-Host "=== Interactive REST Client Tester ===" -ForegroundColor Cyan

$username = Read-Host "Username"
$securePass = Read-Host "Password" -AsSecureString
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
$nonce = New-Nonce -Length 16

$token = Get-AuthTokenFromWpms -Username $username -Password $password -Nonce $nonce
Write-Host " Token obtained" -ForegroundColor Green

$testCount = 0
while ($true) {
    $testCount++
    Write-Host "`nTest $testCount (Ctrl+C to exit)" -ForegroundColor Cyan
    $uri = Read-Host "Endpoint URI"
    $method = (Read-Host "Method [GET]").ToUpper()
    if (-not $method) { $method = 'GET' }
    
    $result = Invoke-RestApiRequest -Method $method -Uri $uri -BearerToken $token
    Write-Host "Success: $($result.Success), Status: $($result.StatusCode)" -ForegroundColor Green
    if ($result.Content) { $result.Content | ConvertTo-Json -Depth 3 | Write-Host }
    
    if ((Read-Host "Another? (y/n) [y]") -eq 'n') { break }
}
Write-Host "`n=== Done ===" -ForegroundColor Cyan
