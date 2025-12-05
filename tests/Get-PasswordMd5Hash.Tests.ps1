Import-Module Pester -ErrorAction SilentlyContinue

# Sourcing the function under test
. "$PSScriptRoot\..\src\Get-AuthToken.ps1"

Describe 'Get-PasswordMd5Hash' {
    It 'computes expected MD5(MD5(password)+nonce) for known input' {
        $password = 'Kik02006!'
        $nonce = 'ABC'
        $expected = 'fa232ddfcd6a69bdddf94ab3c3b46674'

        $result = Get-PasswordMd5Hash -Password $password -Nonce $nonce
        $result | Should -Be $expected
    }

    It 'throws when password is null' {
        { Get-PasswordMd5Hash -Password $null -Nonce 'x' } | Should -Throw
    }

    It 'returns same hash when nonce is empty string' {
        $password = 'test'
        $result1 = Get-PasswordMd5Hash -Password $password -Nonce ''
        $result2 = Get-PasswordMd5Hash -Password $password
        $result1 | Should -Be $result2
    }
}
