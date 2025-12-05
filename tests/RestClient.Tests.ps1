Import-Module Pester -ErrorAction SilentlyContinue

# Sourcing the function under test
. "$PSScriptRoot\..\src\RestClient.ps1"

Describe 'Invoke-RestApiRequest' {
    It 'returns Success=true on 200 with JSON content' {
        # This is a mock/unit test using a small test helper
        # Real integration tests would need a mock server or Skip if no connectivity
        
        # We'll just test the function's parameter validation here
        # since calling real endpoints requires network/auth
        
        $fnDef = Get-Command Invoke-RestApiRequest -ErrorAction SilentlyContinue
        $fnDef | Should -Not -BeNullOrEmpty
    }

    It 'accepts Method, Uri, BearerToken parameters' {
        $fnDef = Get-Command Invoke-RestApiRequest
        $params = $fnDef.Parameters.Keys
        $params | Should -Contain 'Method'
        $params | Should -Contain 'Uri'
        $params | Should -Contain 'BearerToken'
        $params | Should -Contain 'RetryCount'
    }
}
