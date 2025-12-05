Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\..\src\Get-AuthToken.ps1"
. "$scriptRoot\..\src\RestClient.ps1"

Write-Host "=== REST Client Full Test ===" -ForegroundColor Cyan

$username = 'pduarte'
$password = 'Kik02006!'

Write-Host "[Step 1] Generate nonce" -ForegroundColor Yellow
$nonce = New-Nonce -Length 16
Write-Host "Nonce: $nonce" -ForegroundColor Gray

Write-Host "[Step 2] Get bearer token" -ForegroundColor Yellow
$token = Get-AuthTokenFromWpms -Username $username -Password $password -Nonce $nonce
if ($token) {
    Write-Host "OK Token obtained" -ForegroundColor Green
    Write-Host "Token (first 50 chars): $($token.Substring(0, 50))..." -ForegroundColor Gray
} else {
    Write-Error "No token returned"
    exit 1
}

Write-Host "[Step 3] Call protected REST endpoint" -ForegroundColor Yellow
$uri = 'http://wpms/Eve/api/WebService/D0080Dread_all'
$queryParams = @{ ARTC = '{"val1":"1303394"}' }
Write-Host "Endpoint: $uri" -ForegroundColor Gray

$result = Invoke-RestApiRequest -Method GET -Uri $uri -QueryParameters $queryParams -BearerToken $token -Verbose:$false
Write-Host "OK Request completed" -ForegroundColor Green
Write-Host "Success: $($result.Success)" -ForegroundColor Green
Write-Host "HTTP Status: $($result.StatusCode)" -ForegroundColor Green

if ($result.Content) {
    Write-Host "Response has content object" -ForegroundColor Green
}
if ($result.RawContent) {
    $truncated = if ($result.RawContent.Length -gt 150) { "$($result.RawContent.Substring(0, 150))..." } else { $result.RawContent }
    Write-Host "Raw: $truncated" -ForegroundColor Gray
}
if ($result.Error) {
    Write-Host "Error: $($result.Error)" -ForegroundColor Red
}

Write-Host "[Step 4] Test with custom headers" -ForegroundColor Yellow
$headers = @{ 'X-Custom-Header' = 'TestValue' }
$result2 = Invoke-RestApiRequest -Method GET -Uri $uri -QueryParameters $queryParams -BearerToken $token -Headers $headers -Verbose:$false
Write-Host "OK Request with headers completed" -ForegroundColor Green
Write-Host "Success: $($result2.Success), Status: $($result2.StatusCode)" -ForegroundColor Green

Write-Host "=== All Tests Complete ===" -ForegroundColor Cyan
