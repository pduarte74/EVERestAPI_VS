<#
.SYNOPSIS
  Generic REST API caller with bearer token, retries and JSON parsing.

.DESCRIPTION
  Invoke-RestApiRequest is a small helper for Windows PowerShell 5.1 to
  call REST endpoints (GET/POST/PUT/DELETE), attach an Authorization Bearer
  token, send/receive JSON, and return structured results including HTTP
  status code, raw content and parsed JSON when possible.

.PARAMETER Method
  HTTP method string, default 'GET'.

.PARAMETER Uri
  Full request URI or relative path (string). Required.

.PARAMETER QueryParameters
  Hashtable of query parameters to append to the URI (optional).

.PARAMETER Headers
  Additional headers as a hashtable (optional).

.PARAMETER Body
  Body object or string. If object, it's converted to JSON and Content-Type set to application/json.

.PARAMETER BearerToken
  If supplied, adds Authorization: Bearer <token> header.

.PARAMETER TimeoutSec
  Request timeout in seconds (default 60).

.PARAMETER RetryCount
  Number of retry attempts on transient failure (default 2).

.PARAMETER RetryDelaySeconds
  Delay between retries in seconds (default 2).

.OUTPUTS
  PSCustomObject with keys: Success (bool), StatusCode (int), RawContent (string), Content (deserialized object or null), Error (string|null)

.EXAMPLE
  $r = Invoke-RestApiRequest -Method GET -Uri 'http://wpms/Eve/api/WebService/D0080Dread_all' -QueryParameters @{ ARTC = '{"val1":"1303394"}' } -BearerToken $token
  if ($r.Success) { $r.Content } else { Write-Error $r.Error }
#>

function Invoke-RestApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)] [ValidateSet('GET','POST','PUT','DELETE','PATCH')] [string]$Method = 'GET',
        [Parameter(Mandatory=$true)] [string]$Uri,
        [hashtable]$QueryParameters,
        [hashtable]$Headers,
        [Parameter(Mandatory=$false)] $Body,
        [string]$BearerToken,
        [int]$TimeoutSec = 60,
        [int]$RetryCount = 2,
        [int]$RetryDelaySeconds = 2,
        [switch]$ShowCurl,
        [string]$CurlFilePath
    )

    begin {
        if (-not $Headers) { $Headers = @{} }
        if ($BearerToken) { $Headers['Authorization'] = "Bearer $BearerToken" }
        if (-not $Headers.ContainsKey('accept')) { $Headers['accept'] = 'application/json' }

        # Build query string if provided
        if ($QueryParameters) {
            $qpairs = @()
            foreach ($k in $QueryParameters.Keys) {
                $v = $QueryParameters[$k]
                # If value is a hashtable/object, convert to JSON
                if ($v -is [hashtable] -or $v -is [pscustomobject]) {
                    $v = $v | ConvertTo-Json -Compress
                }
                $v = [string]$v
                $qpairs += ("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString($v))
            }
            $qs = ($qpairs -join '&')
            if ($Uri -match '\?') {
                $Uri = $Uri + '&' + $qs
            } else {
                $Uri = $Uri + '?' + $qs
            }
        }

        # Prepare body and content-type
        $contentType = $null
        $bodyToSend = $null
        if ($PSBoundParameters.ContainsKey('Body') -and $Body -ne $null) {
            if ($Body -is [string]) {
                $bodyToSend = $Body
                $contentType = 'application/json'
            }
            else {
                $bodyToSend = ConvertTo-Json $Body -Depth 10
                $contentType = 'application/json'
            }
        }
    }

    process {
        $attempt = 0
        while ($true) {
            try {
                $attempt++

                # Build equivalent curl command (optional)
                if ($ShowCurl -and $attempt -eq 1) {
                  $curlParts = @()
                  $curlParts += 'curl'
                  $curlParts += ("-X {0}" -f $Method)

                  # Headers
                  foreach ($h in $Headers.GetEnumerator()) {
                    $hn = $h.Key
                    $hv = $h.Value -as [string]
                    if ($hv -ne $null -and $hv -ne '') {
                      $safeHv = $hv.Replace('"', '\\"')
                      $curlParts += "-H `"$($hn): $safeHv`""
                    }
                  }

                  # Body
                  if ($bodyToSend) {
                    $safeBody = $bodyToSend.Replace("'", "\\'")
                    $curlParts += "--data-raw '$safeBody'"
                  }

                  # URL (already contains query string if present)
                  $curlParts += "`"$Uri`""

                  $curlCmd = $curlParts -join ' '

                  Write-Host "[CURL] $curlCmd" -ForegroundColor DarkYellow
                  if ($CurlFilePath) {
                    try { Add-Content -Path $CurlFilePath -Value $curlCmd } catch { }
                  }
                }

                # Choose Invoke-WebRequest to capture raw content and status code
                $invokeParams = @{ Uri = $Uri; Method = $Method; Headers = $Headers; TimeoutSec = $TimeoutSec; ErrorAction = 'Stop' }
                if ($bodyToSend) { $invokeParams['Body'] = $bodyToSend; $invokeParams['ContentType'] = $contentType }

                $resp = Invoke-WebRequest @invokeParams

                $raw = $resp.Content
                $status = $resp.StatusCode

                # Try parse JSON when content-type indicates JSON or content looks like JSON
                $parsed = $null
                try {
                    if ($raw -and ($resp.Headers['Content-Type'] -and $resp.Headers['Content-Type'] -match 'application/json' -or $raw.TrimStart().StartsWith('{') -or $raw.TrimStart().StartsWith('['))) {
                        $parsed = ConvertFrom-Json $raw -ErrorAction Stop
                    }
                }
                catch {
                    # leave parsed as null if JSON parsing fails
                }

                return [PSCustomObject]@{
                    Success = $true
                    StatusCode = $status
                    RawContent = $raw
                    Content = $parsed
                    Error = $null
                }
            }
            catch {
                $err = $_
                # Try to extract HTTP status and response body from the exception if present
                $status = $null; $raw = $null
                if ($_.Exception.Response -ne $null) {
                    try { $status = $_.Exception.Response.StatusCode.Value__ } catch { }
                    try { $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream()); $raw = $reader.ReadToEnd(); $reader.Close() } catch { }
                }

                # Determine if we should retry (5xx or network errors)
                $shouldRetry = $false
                if ($status -and ($status -ge 500 -and $status -lt 600)) { $shouldRetry = $true }
                elseif (-not $status) { $shouldRetry = $true }

                if ($shouldRetry -and $attempt -le $RetryCount) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                    continue
                }

                return [PSCustomObject]@{
                    Success = $false
                    StatusCode = $status
                    RawContent = $raw
                    Content = $null
                    Error = ($err.Exception.Message -as [string])
                }
            }
        }
    }
}

try { Export-ModuleMember -Function Invoke-RestApiRequest } catch { }
