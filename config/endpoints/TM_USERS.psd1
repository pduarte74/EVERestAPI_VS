# Endpoint configuration for TM_USERS (I0002read_I0002V03)

@{
    Name = "I0002read_I0002V03 - TM_USERS"
    Uri = "/Eve/api/WebService/I0002read_I0002V03"
    Parameters = @{}
    TargetTable = "dbo.TM_USERS"
    Description = "Retrieve all users from EVE system"
    
    # SQL Table Schema
    TableSchema = @{
        Columns = @(
            @{ Name = "Utente"; Type = "NVARCHAR(50)"; PrimaryKey = $true }
            @{ Name = "Utente_nome"; Type = "NVARCHAR(200)" }
            @{ Name = "Utente_adm"; Type = "NVARCHAR(10)" }
            @{ Name = "Utente_gruppo"; Type = "NVARCHAR(50)" }
            @{ Name = "Lingua_codice"; Type = "NVARCHAR(10)" }
            @{ Name = "Menu_rf"; Type = "NVARCHAR(50)" }
            @{ Name = "Menu_codice"; Type = "NVARCHAR(50)" }
            @{ Name = "Password_no_rule"; Type = "NVARCHAR(10)" }
            @{ Name = "Trace_accesso"; Type = "NVARCHAR(10)" }
            @{ Name = "Codice_validazione"; Type = "NVARCHAR(200)" }
            @{ Name = "Installazione"; Type = "NVARCHAR(200)" }
            @{ Name = "Preferenze"; Type = "NVARCHAR(MAX)" }
            @{ Name = "Style_sheet"; Type = "NVARCHAR(200)" }
            @{ Name = "Std_datamod"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_utente"; Type = "NVARCHAR(50)" }
            @{ Name = "RetrievedAt"; Type = "DATETIME2(3)"; Default = "GETDATE()" }
        )
    }
    
    # Field Mappings (JSON field -> SQL column)
    FieldMappings = @{
        Utente = "Utente"
        Utente_nome = "Utente_nome"
        Utente_adm = "Utente_adm"
        Utente_gruppo = "Utente_gruppo"
        Lingua_codice = "Lingua_codice"
        Menu_rf = "Menu_rf"
        Menu_codice = "Menu_codice"
        Password_no_rule = "Password_no_rule"
        Trace_accesso = "Trace_accesso"
        Codice_validazione = "Codice_validazione"
        Installazione = "Installazione"
        Preferenze = "Preferenze"
        Style_sheet = "Style_sheet"
        Std_datamod = "Std_datamod"
        Std_utente = "Std_utente"
    }
}
