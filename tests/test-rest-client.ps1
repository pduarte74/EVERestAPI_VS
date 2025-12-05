<#
.SYNOPSIS
  Interactive REST client tester for exploring different WPMS endpoints.

.DESCRIPTION
  This script allows you to test Invoke-RestApiRequest against various
  REST endpoints with custom methods, parameters, headers, and bearer tokens.
  Useful for development and debugging.

.EXAMPLE
  PS> .\tests\test-rest-client.ps1
  (Prompts for endpoint, method, parameters, and credentials interactively)
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\..\src\Get-AuthToken.ps1"
. "$scriptRoot\..\src\RestClient.ps1"

Write-Host "=== Interactive REST Client Tester ===" -ForegroundColor Cyan
Write-Host "Test different WPMS endpoints with custom parameters and methods.`n" -ForegroundColor Gray

# Get credentials
Write-Host "[Step 1] Credentials" -ForegroundColor Yellow
$username = Read-Host "Username"
$securePass = Read-Host "Password" -AsSecureString
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
$nonce = New-Nonce -Length 16
Write-Host "Generated nonce: $nonce`n" -ForegroundColor Gray

# Get token
Write-Host "[Step 2] Authenticating..." -ForegroundColor Yellow
try {
    $token = Get-AuthTokenFromWpms -Username $username -Password $password -Nonce $nonce -ErrorAction Stop
    if ($token) {
        Write-Host "✓ Token obtained`n" -ForegroundColor Green
    } else {
        throw "No token returned"
    }
}
catch {
    Write-Error "Authentication failed: $_"
    exit 1
}

# Interactive endpoint testing loop
$testCount = 0
while ($true) {
    Write-Host "`n[Test $($testCount + 1)]" -ForegroundColor Cyan
    Write-Host "Endpoint Configuration (press Ctrl+C to exit)" -ForegroundColor Gray

    # Endpoint URI
    $defaultUri = 'http://wpms/Eve/api/WebService/D0080Dread_all'
    $uri = Read-Host "Endpoint URI [$defaultUri]"
    if (-not $uri) { $uri = $defaultUri }

    # HTTP Method
    $defaultMethod = 'GET'
    $methodPrompt = Read-Host "HTTP Method [GET/POST/PUT/DELETE] [$defaultMethod]"
    if (-not $methodPrompt) { $methodPrompt = $defaultMethod }
    $method = $methodPrompt.ToUpper()

    # Query parameters (JSON format)
    $queryStr = Read-Host "Query parameters as JSON e.g., {`"ARTC`":`"{...}`"} (leave blank for none)"
    $queryParams = $null
    if ($queryStr) {
        try {
            $queryParams = $queryStr | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-Warning "Could not parse query params as JSON: $_"
            $queryParams = $null
        }
    }

    # Request body (for POST/PUT)
    $bodyStr = $null
    if ($method -in 'POST', 'PUT', 'PATCH') {
        $bodyStr = Read-Host "Request body as JSON (leave blank for none)"
    }

    # Additional headers (JSON format)
    $headersStr = Read-Host "Additional headers as JSON e.g., {`"X-Custom`":`"value`"} (leave blank for none)"
    $headers = $null
    if ($headersStr) {
        try {
            $headers = $headersStr | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-Warning "Could not parse headers as JSON: $_"
            $headers = $null
        }
    }

    # Timeout
    $timeoutStr = Read-Host "Timeout in seconds [60]"
    $timeout = if ($timeoutStr) { [int]$timeoutStr } else { 60 }

    # Execute request
    Write-Host "`n[Executing]" -ForegroundColor Yellow
    Write-Host "  Method: $method" -ForegroundColor Gray
    Write-Host "  URI: $uri" -ForegroundColor Gray
    if ($queryParams) { Write-Host "  Query Params: $($queryParams | ConvertTo-Json -Compress)" -ForegroundColor Gray }
    if ($bodyStr) { Write-Host "  Body: $bodyStr" -ForegroundColor Gray }
    Write-Host ""

    try {
        $invokeParams = @{
            Method = $method
            Uri = $uri
            BearerToken = $token
            TimeoutSec = $timeout
            RetryCount = 1
            Verbose = $true
        }
        if ($queryParams) { $invokeParams['QueryParameters'] = $queryParams }
        if ($bodyStr) { $invokeParams['Body'] = $bodyStr }
        if ($headers) { $invokeParams['Headers'] = $headers }

        $result = Invoke-RestApiRequest @invokeParams

        Write-Host "`n[Result]" -ForegroundColor Green
        Write-Host "  Success: $($result.Success)" -ForegroundColor Green
        Write-Host "  Status Code: $($result.StatusCode)" -ForegroundColor Green

        if ($result.Success -and $result.Content) {
            Write-Host "`n[Parsed Content]" -ForegroundColor Green
            $result.Content | ConvertTo-Json -Depth 5 | Write-Host
        }
        elseif ($result.RawContent) {
            Write-Host "`n[Raw Response]" -ForegroundColor Green
            Write-Host $result.RawContent
        }

        if ($result.Error) {
            Write-Host "`n[Error]" -ForegroundColor Red
            Write-Host $result.Error
        }

        # Save to file option
        $saveChoice = Read-Host "`nSave response to file? (y/n) [n]"
        if ($saveChoice -eq 'y') {
            $filename = Read-Host "Filename (default: response_$(Get-Date -Format 'yyyyMMdd_HHmmss').json)"
            if (-not $filename) { $filename = "response_$(Get-Date -Format 'yyyyMMdd_HHmmss').json" }
            if ($result.Content) {
                $result.Content | ConvertTo-Json -Depth 10 | Out-File -FilePath $filename -Encoding UTF8
            }
            else {
                $result.RawContent | Out-File -FilePath $filename -Encoding UTF8
            }
            Write-Host "✓ Saved to $filename" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Request failed: $_"
    }

    $testCount++
    $continueChoice = Read-Host "`nTest another endpoint? (y/n) [y]"
    if ($continueChoice -eq 'n') {
        Write-Host "`n=== Test Session Complete ===" -ForegroundColor Cyan
        break
    }
}
