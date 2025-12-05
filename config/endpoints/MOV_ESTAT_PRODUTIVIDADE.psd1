# Endpoint configuration for MOV_ESTAT_PRODUTIVIDADE (FAPLOGR011showStatsErrors)

@{
    Name = "FAPLOGR011showStatsErrors - MOV_ESTAT_PRODUTIVIDADE"
    Uri = "/Eve/api/WebService/FAPLOGR011showStatsErrors"
    Method = "GET"
    Parameters = @{
        ENTI = @{ val1 = "('92','93')"; sig1 = "IN" }
        # Date parameter: Monday of previous week (calculated dynamically by integration script)
        DTVL = @{ val1 = "DYNAMIC:PreviousMondayDate"; sig1 = "GE" }
    }
    TargetTable = "dbo.MOV_ESTAT_PRODUTIVIDADE"
    Description = "Retrieve productivity statistics and errors by operator"
    
    # SQL Table Schema
    TableSchema = @{
        Columns = @(
            @{ Name = "Date"; Type = "DATE"; PrimaryKey = $true }
            @{ Name = "Whrs"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Oprt"; Type = "NVARCHAR(20)"; PrimaryKey = $true }
            @{ Name = "WrkType"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Dprt"; Type = "NVARCHAR(50)" }
            @{ Name = "Shift"; Type = "NVARCHAR(4)" }
            @{ Name = "Team"; Type = "NVARCHAR(4)" }
            @{ Name = "QttPicked"; Type = "DECIMAL(18,3)" }
            @{ Name = "QttPicked2"; Type = "DECIMAL(18,3)" }
            @{ Name = "QttChecked"; Type = "DECIMAL(18,3)" }
            @{ Name = "QttChecked2"; Type = "DECIMAL(18,3)" }
            @{ Name = "QttCounted"; Type = "DECIMAL(18,3)" }
            @{ Name = "QttCounted2"; Type = "DECIMAL(18,3)" }
            @{ Name = "TimeSpent"; Type = "INT" }
            @{ Name = "TimeUm"; Type = "NVARCHAR(4)" }
            @{ Name = "NrSusp"; Type = "INT" }
            @{ Name = "NrActions"; Type = "INT" }
            @{ Name = "NrContainers"; Type = "INT" }
            @{ Name = "HorizDistance"; Type = "DECIMAL(18,3)" }
            @{ Name = "VertDistance"; Type = "DECIMAL(18,3)" }
            @{ Name = "Numero_linee"; Type = "INT" }
            @{ Name = "DistUM"; Type = "NVARCHAR(10)" }
            @{ Name = "DifQtt"; Type = "DECIMAL(18,3)" }
            @{ Name = "DiffQtt2"; Type = "DECIMAL(18,3)" }
            @{ Name = "NrErrors"; Type = "INT" }
            @{ Name = "RetrievedAt"; Type = "DATETIME2(3)"; Default = "GETDATE()" }
        )
    }
    
    # Field Mappings (JSON field -> SQL column)
    FieldMappings = @{
        Date = "Date"
        Whrs = "Whrs"
        Dprt = "Dprt"
        Oprt = "Oprt"
        WrkType = "WrkType"
        Shift = "Shift"
        Team = "Team"
        QttPicked = "QttPicked"
        QttPicked2 = "QttPicked2"
        QttChecked = "QttChecked"
        QttChecked2 = "QttChecked2"
        QttCounted = "QttCounted"
        QttCounted2 = "QttCounted2"
        TimeSpent = "TimeSpent"
        TimeUm = "TimeUm"
        NrSusp = "NrSusp"
        NrActions = "NrActions"
        NrContainers = "NrContainers"
        HorizDistance = "HorizDistance"
        VertDistance = "VertDistance"
        Numero_linee = "Numero_linee"
        DistUM = "DistUM"
        DifQtt = "DifQtt"
        DiffQtt2 = "DiffQtt2"
        NrErrors = "NrErrors"
    }
}
