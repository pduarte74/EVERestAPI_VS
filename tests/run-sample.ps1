<#
.SYNOPSIS
  Sample script demonstrating the full flow:
  1. Get auth token from WPMS login endpoint
  2. Call a protected REST endpoint with the token
  3. Display results (or write to DB/CSV)

.DESCRIPTION
  This is a runnable example showing how to:
  - Use Get-AuthTokenFromWpms to obtain a bearer token
  - Use Invoke-RestApiRequest to call a protected REST endpoint
  - Handle the response (Success/Error)
  - Optionally write results to a CSV file or database

.EXAMPLE
  PS> .\tests\run-sample.ps1
  (Prompts for credentials, gets token, calls API, displays results)

.EXAMPLE
  PS> $creds = @{ Username='pduarte'; Password='Kik02006!'; Nonce='ABC' }
      .\tests\run-sample.ps1 @creds
  (Uses provided credentials without prompts)
#>

param(
    [string]$Username,
    [string]$Password,
    [string]$Nonce = 'ABC',
    [string]$ApiEndpoint = 'http://wpms/Eve/api/WebService/D0080Dread_all',
    [hashtable]$QueryParams = @{ ARTC = '{"val1":"1303394"}' },
    [string]$OutputFile  # Optional CSV file to save results
)

# Import helper functions
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\..\src\Get-AuthToken.ps1"
. "$scriptRoot\..\src\RestClient.ps1"

Write-Host "=== EVERestAPI Sample Run ===" -ForegroundColor Cyan

# Step 1: Get token
Write-Host "`n[1/3] Obtaining auth token..." -ForegroundColor Yellow
try {
    $token = Get-AuthTokenFromWpms -Username $Username -Password $Password -Nonce $Nonce -Verbose
    if ($token) {
        Write-Host "✓ Token obtained successfully" -ForegroundColor Green
        Write-Host "Token (truncated): $($token.Substring(0, 30))..." -ForegroundColor Gray
    } else {
        throw "No token returned"
    }
}
catch {
    Write-Error "Failed to obtain token: $_"
    exit 1
}

# Step 2: Call protected API endpoint
Write-Host "`n[2/3] Calling REST API endpoint..." -ForegroundColor Yellow
try {
    $apiResult = Invoke-RestApiRequest `
        -Method GET `
        -Uri $ApiEndpoint `
        -QueryParameters $QueryParams `
        -BearerToken $token `
        -RetryCount 2 `
        -Verbose

    if ($apiResult.Success) {
        Write-Host "✓ API call successful (HTTP $($apiResult.StatusCode))" -ForegroundColor Green
    } else {
        throw "API returned error: $($apiResult.Error) (HTTP $($apiResult.StatusCode))"
    }
}
catch {
    Write-Error "Failed to call API: $_"
    exit 1
}

# Step 3: Display/save results
Write-Host "`n[3/3] Processing results..." -ForegroundColor Yellow

if ($apiResult.Content) {
    Write-Host "✓ Response parsed as JSON:" -ForegroundColor Green
    $apiResult.Content | ConvertTo-Json -Depth 3 | Write-Host

    # Optional: Save to CSV
    if ($OutputFile) {
        try {
            # Convert object to flat structure for CSV export
            $flat = $apiResult.Content | Select-Object -Property * -Exclude PSPath, PSParentPath, PSChildName, PSDrive, PSProvider
            $flat | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            Write-Host "✓ Results saved to: $OutputFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not save to CSV: $_"
        }
    }
}
else {
    Write-Host "Response (raw text):" -ForegroundColor Green
    $apiResult.RawContent | Write-Host
}

Write-Host "`n=== Sample Run Complete ===" -ForegroundColor Cyan
