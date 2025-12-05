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
    
    # API Endpoints to call
    Endpoints = @(
        @{
            Name = "D0080Dread_all - With ARTC parameter"
            Uri = "/Eve/api/WebService/D0080Dread_all"
            Parameters = @{
                ARTC = '{"val1":"1303394"}'
            }
        },
        @{
            Name = "D0081read_all - Simple ARTC"
            Uri = "/Eve/api/WebService/D0081read_all"
            Parameters = @{
                ARTC = '{"val1":"1303394"}'
            }
        }
    )
}
