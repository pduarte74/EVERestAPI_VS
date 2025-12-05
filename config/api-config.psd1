# Configuration file for WPMS API calls
# Format: PowerShell data file (.psd1)

@{
    # API Server
    Server = "http://wpms.prodout.com"
    
    # Credentials
    Credentials = @{
        Username = "pduarte"
        # Password is stored encrypted in secure-password.txt
        # Run config\Setup-SecurePassword.ps1 to create/update the encrypted password file
        SecurePasswordFile = "secure-password.txt"
    }

    # SQL Server Configuration
    SqlConnectionString = "Server=sql-os-prd-01.rede.local;Database=EVEReporting;Integrated Security=True;Encrypt=False;"
    SqlTable = "dbo.WpmsApiResults"
    
    # Endpoint Configuration Files (relative to config folder)
    EndpointConfigFiles = @(
        "endpoints\TM_USERS.psd1"
        "endpoints\TM_UDT.psd1"
        "endpoints\TM_EQUIPA.psd1"
        "endpoints\MOV_ESTAT_PRODUTIVIDADE.psd1"
    )
}
