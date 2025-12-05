# Endpoint configuration for TM_EQUIPA (D0256Dread_all)

@{
    Name = "D0256Dread_all - TM_EQUIPA"
    Uri = "/Eve/api/WebService/D0256Dread_all"
    Parameters = @{}
    TargetTable = "dbo.TM_EQUIPA"
    Description = "Retrieve all EQUIPA (Team) descriptions"
    
    # SQL Table Schema
    TableSchema = @{
        Columns = @(
            @{ Name = "Squadra"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Lingua_codice"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Descrizione_tipo"; Type = "NVARCHAR(10)" }
            @{ Name = "Descrizione_testo"; Type = "NVARCHAR(500)" }
            @{ Name = "Validita_inizio"; Type = "NVARCHAR(20)" }
            @{ Name = "Validita_fine"; Type = "NVARCHAR(20)" }
            @{ Name = "Std_f1"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_f2"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_f3"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_f4"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_datamod"; Type = "NVARCHAR(20)" }
            @{ Name = "Std_programma"; Type = "NVARCHAR(50)" }
            @{ Name = "Std_utente"; Type = "NVARCHAR(50)" }
            @{ Name = "RetrievedAt"; Type = "DATETIME2(3)"; Default = "GETDATE()" }
        )
    }
    
    # Field Mappings (JSON field -> SQL column)
    FieldMappings = @{
        Squadra = "Squadra"
        Lingua_codice = "Lingua_codice"
        Descrizione_tipo = "Descrizione_tipo"
        Descrizione_testo = "Descrizione_testo"
        Validita_inizio = "Validita_inizio"
        Validita_fine = "Validita_fine"
        Std_f1 = "Std_f1"
        Std_f2 = "Std_f2"
        Std_f3 = "Std_f3"
        Std_f4 = "Std_f4"
        Std_datamod = "Std_datamod"
        Std_programma = "Std_programma"
        Std_utente = "Std_utente"
    }
}
