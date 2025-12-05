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
            @{ Name = "Date"; Type = "NVARCHAR(8)"; PrimaryKey = $true }
            @{ Name = "Whrs"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Oprt"; Type = "NVARCHAR(20)"; PrimaryKey = $true }
            @{ Name = "WrkType"; Type = "NVARCHAR(10)"; PrimaryKey = $true }
            @{ Name = "Dprt"; Type = "NVARCHAR(50)" }
            @{ Name = "Shift"; Type = "NVARCHAR(4)" }
            @{ Name = "Team"; Type = "NVARCHAR(4)" }
            @{ Name = "QttPicked"; Type = "NVARCHAR(50)" }
            @{ Name = "QttPicked2"; Type = "NVARCHAR(50)" }
            @{ Name = "QttChecked"; Type = "NVARCHAR(50)" }
            @{ Name = "QttChecked2"; Type = "NVARCHAR(50)" }
            @{ Name = "QttCounted"; Type = "NVARCHAR(50)" }
            @{ Name = "QttCounted2"; Type = "NVARCHAR(50)" }
            @{ Name = "TimeSpent"; Type = "NVARCHAR(50)" }
            @{ Name = "TimeUm"; Type = "NVARCHAR(4)" }
            @{ Name = "NrSusp"; Type = "NVARCHAR(50)" }
            @{ Name = "NrActions"; Type = "NVARCHAR(50)" }
            @{ Name = "NrContainers"; Type = "NVARCHAR(50)" }
            @{ Name = "HorizDistance"; Type = "NVARCHAR(50)" }
            @{ Name = "VertDistance"; Type = "NVARCHAR(50)" }
            @{ Name = "Numero_linee"; Type = "NVARCHAR(50)" }
            @{ Name = "DistUM"; Type = "NVARCHAR(10)" }
            @{ Name = "DifQtt"; Type = "NVARCHAR(50)" }
            @{ Name = "DiffQtt2"; Type = "NVARCHAR(50)" }
            @{ Name = "NrErrors"; Type = "NVARCHAR(50)" }
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
