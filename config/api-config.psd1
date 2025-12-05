# Configuration file for WPMS API calls
# Format: PowerShell data file (.psd1)

@{
    # API Server
    Server = "http://wpms.prodout.com"
    
    # Credentials
    Credentials = @{
        Username = "pduarte"
        Password = "Kik02006!"
    }

    # SQL Server Configuration
    SqlConnectionString = "Server=sql-os-prd-01.rede.local;Database=EVEReporting;Integrated Security=True;Encrypt=False;"
    SqlTable = "dbo.WpmsApiResults"
    
    # API Endpoints to call
    Endpoints = @(
        @{
            Name = "I0002read_I0002V03 - TM_USERS"
            Uri = "/Eve/api/WebService/I0002read_I0002V03"
            Parameters = @{}
            TargetTable = "dbo.TM_USERS"
        }
    )
}
