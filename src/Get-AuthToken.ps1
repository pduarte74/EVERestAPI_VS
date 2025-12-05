<#
.SYNOPSIS
  Obtains a bearer token from the WPMS login endpoint.

.DESCRIPTION
  Posts JSON credentials (username, password, nonce) to the configured
  login endpoint and returns the token value. Designed for Windows PowerShell 5.1.

.PARAMETER Username
  The username for login. If omitted the function will prompt for it.

.PARAMETER Password
  The password for login. If omitted the function will prompt securely.

.PARAMETER Nonce
  Optional nonce value required by the API. If omitted, an empty string is sent.

.PARAMETER Endpoint
  The full URL of the login endpoint. Defaults to 'http://wpms/Eve/api/login'.

.PARAMETER ReturnFullResponse
  If set, the entire deserialized JSON response object is returned instead of a single token string.

.EXAMPLE
  $token = Get-AuthTokenFromWpms -Username 'alice' -Password 's3cr3t' -Nonce '1234'

.EXAMPLE
  # Prompt for credentials interactively
  $token = Get-AuthTokenFromWpms -Nonce '1234'

#>

function Get-AuthTokenFromWpms {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Username,

        [Parameter(Position=1)]
        [string]$Password,

        [Parameter(Position=2)]
        [string]$Nonce = '',

      [Parameter()]
      [switch]$SkipHash,

        [Parameter()]
        [string]$Endpoint = 'http://wpms/Eve/api/login',

        [switch]$ReturnFullResponse
    )

    begin {
        if (-not $Username) {
            $Username = Read-Host -Prompt 'Username'
        }
        if (-not $Password) {
            # Secure prompt for password, then convert to plain string for the JSON body
            $secure = Read-Host -Prompt 'Password' -AsSecureString
            $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        }

      # If no nonce provided, generate a cryptographically-random nonce
      if ([string]::IsNullOrWhiteSpace($Nonce)) {
        $Nonce = New-Nonce -Length 16
        Write-Verbose "Generated nonce: $Nonce"
      }
      # By default, hash the password as MD5(MD5(password)+nonce). Use -SkipHash to send plain password.
      if ($SkipHash) {
        $passwordToSend = $Password
      }
      else {
        $passwordToSend = Get-PasswordMd5Hash -Password $Password -Nonce $Nonce
      }

      $headers = @{ 'accept' = 'application/json' }
      $bodyObj = @{ username = $Username; password = $passwordToSend; nonce = $Nonce }
      $bodyJson = ConvertTo-Json $bodyObj -Depth 3
    }

    process {
        try {
            $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -ContentType 'application/json' -Body $bodyJson -ErrorAction Stop

            # Common token properties: 'token', 'access_token', 'accessToken' — return whichever exists
            if ($ReturnFullResponse) {
                return $response
            }

            if ($null -ne $response.token) { return $response.token }
            if ($null -ne $response.access_token) { return $response.access_token }
            if ($null -ne $response.accessToken) { return $response.accessToken }

            # If token property not present, return the entire response as fallback
            return $response
        }
        catch {
          Write-Error ("Failed to obtain token from {0}: {1}" -f $Endpoint, $_.Exception.Message)
          return $null
        }
    }
}

function Get-PasswordMd5Hash {
    <#
    .SYNOPSIS
      Compute MD5(MD5(Password) + Nonce) and return as lowercase hex string.

    .PARAMETER Password
      The plain-text password to hash.

    .PARAMETER Nonce
      The nonce to append to the inner MD5 hex string before the outer MD5.

    .EXAMPLE
      Get-PasswordMd5Hash -Password 'mypassword' -Nonce '1234'

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Password,

        [Parameter(Position=1)]
        [string]$Nonce = ''
    )

    process {
        if ($Password -eq $null) { throw 'Password is required.' }

        $encoding = [System.Text.Encoding]::UTF8

        # Compute inner MD5(password)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $innerBytes = $encoding.GetBytes($Password)
        $innerHashBytes = $md5.ComputeHash($innerBytes)
        $innerHash = ($innerHashBytes | ForEach-Object { $_.ToString('x2') }) -join ''

        # Concatenate inner hex + nonce (PowerShell 5.1 doesn't have ?: operator)
        if ($Nonce -ne $null -and $Nonce -ne '') {
          $combined = $innerHash + $Nonce
        }
        else {
          $combined = $innerHash
        }

        # Compute outer MD5(innerHash + nonce)
        $combinedBytes = $encoding.GetBytes($combined)
        $outerHashBytes = $md5.ComputeHash($combinedBytes)
        $outerHash = ($outerHashBytes | ForEach-Object { $_.ToString('x2') }) -join ''

        return $outerHash
    }
}

try {
  Export-ModuleMember -Function Get-AuthTokenFromWpms,Get-PasswordMd5Hash
}
catch {
  # Running outside of a module (dot-sourced); ignore export error
}

function New-Nonce {
    <#
    .SYNOPSIS
      Generate a cryptographically random nonce string.

    .PARAMETER Length
      Desired length in characters (default 16). Uses GUIDs and repeats as necessary.

    .EXAMPLE
      New-Nonce -Length 16
    #>
    param(
        [Parameter(Position=0)]
        [int]$Length = 16
    )

    # Use Guid as a convenient hex source; repeat until we have enough characters
    $builder = ''
    while ($builder.Length -lt $Length) {
        $builder += [System.Guid]::NewGuid().ToString('N')
    }

    return $builder.Substring(0, $Length)
}
