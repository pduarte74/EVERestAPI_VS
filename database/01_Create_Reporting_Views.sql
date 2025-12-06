-- =============================================
-- WPMS API Integration - Reporting Views
-- =============================================
-- Description: SQL views for productivity reporting and analysis
-- Database: EVEReporting
-- Author: Pedro Duarte
-- Date: 2025-12-06
-- =============================================

USE [EVEReporting]
GO

-- =============================================
-- View 1: Daily Productivity Summary by Operator
-- =============================================
-- Description: Summarizes daily productivity metrics for each operator
-- Usage: SELECT * FROM vw_DailyProductivityByOperator WHERE Date >= '2025-01-01'
-- =============================================

IF OBJECT_ID('dbo.vw_DailyProductivityByOperator', 'V') IS NOT NULL
    DROP VIEW dbo.vw_DailyProductivityByOperator
GO

CREATE VIEW dbo.vw_DailyProductivityByOperator
AS
SELECT 
    m.[Date],
    DATENAME(weekday, m.[Date]) AS DayOfWeek,
    m.Oprt AS OperatorCode,
    u.Name AS OperatorName,
    u.Email AS OperatorEmail,
    m.Whrs AS Warehouse,
    m.WrkType AS WorkTypeCode,
    w.Name AS WorkTypeName,
    m.Dprt AS Department,
    m.Shift,
    m.Team,
    e.Name AS TeamName,
    
    -- Picking Metrics
    ISNULL(m.QttPicked, 0) AS QtyPicked,
    ISNULL(m.QttPicked2, 0) AS QtyPicked2,
    
    -- Checking Metrics
    ISNULL(m.QttChecked, 0) AS QtyChecked,
    ISNULL(m.QttChecked2, 0) AS QtyChecked2,
    
    -- Counting Metrics
    ISNULL(m.QttCounted, 0) AS QtyCounted,
    ISNULL(m.QttCounted2, 0) AS QtyCounted2,
    
    -- Time Metrics
    ISNULL(m.TimeSpent, 0) AS TimeSpent,
    m.TimeUm AS TimeUnit,
    
    -- Activity Metrics
    ISNULL(m.NrSusp, 0) AS NumberOfSuspensions,
    ISNULL(m.NrActions, 0) AS NumberOfActions,
    ISNULL(m.NrContainers, 0) AS NumberOfContainers,
    ISNULL(m.Numero_linee, 0) AS NumberOfLines,
    
    -- Distance Metrics
    ISNULL(m.HorizDistance, 0) AS HorizontalDistance,
    ISNULL(m.VertDistance, 0) AS VerticalDistance,
    m.DistUM AS DistanceUnit,
    
    -- Quality Metrics
    ISNULL(m.DifQtt, 0) AS DifferenceQty,
    ISNULL(m.DiffQtt2, 0) AS DifferenceQty2,
    ISNULL(m.NrErrors, 0) AS NumberOfErrors,
    
    -- Calculated Metrics
    CASE 
        WHEN ISNULL(m.TimeSpent, 0) > 0 THEN 
            CAST(ISNULL(m.QttPicked, 0) AS DECIMAL(18,2)) / NULLIF(m.TimeSpent, 0)
        ELSE 0 
    END AS PicksPerTimeUnit,
    
    CASE 
        WHEN ISNULL(m.QttPicked, 0) > 0 THEN 
            CAST(ISNULL(m.NrErrors, 0) AS DECIMAL(18,4)) / NULLIF(m.QttPicked, 0) * 100
        ELSE 0 
    END AS ErrorRatePercent,
    
    m.RetrievedAt AS LastUpdated
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
    LEFT JOIN dbo.TM_USERS u ON m.Oprt = u.Operator
    LEFT JOIN dbo.TM_UDT w ON m.WrkType = w.WrkType
    LEFT JOIN dbo.TM_EQUIPA e ON m.Team = e.Team
GO

-- =============================================
-- View 2: Weekly Productivity Summary
-- =============================================
-- Description: Aggregates productivity by week and operator
-- Usage: SELECT * FROM vw_WeeklyProductivitySummary WHERE Year = 2025
-- =============================================

IF OBJECT_ID('dbo.vw_WeeklyProductivitySummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_WeeklyProductivitySummary
GO

CREATE VIEW dbo.vw_WeeklyProductivitySummary
AS
SELECT 
    YEAR(m.[Date]) AS [Year],
    DATEPART(ISO_WEEK, m.[Date]) AS WeekNumber,
    MIN(m.[Date]) AS WeekStartDate,
    MAX(m.[Date]) AS WeekEndDate,
    m.Oprt AS OperatorCode,
    u.Name AS OperatorName,
    m.Team,
    e.Name AS TeamName,
    
    -- Aggregated Quantities
    SUM(ISNULL(m.QttPicked, 0)) AS TotalQtyPicked,
    SUM(ISNULL(m.QttChecked, 0)) AS TotalQtyChecked,
    SUM(ISNULL(m.QttCounted, 0)) AS TotalQtyCounted,
    
    -- Aggregated Time
    SUM(ISNULL(m.TimeSpent, 0)) AS TotalTimeSpent,
    
    -- Aggregated Activities
    SUM(ISNULL(m.NrActions, 0)) AS TotalActions,
    SUM(ISNULL(m.NrContainers, 0)) AS TotalContainers,
    SUM(ISNULL(m.Numero_linee, 0)) AS TotalLines,
    
    -- Aggregated Distance
    SUM(ISNULL(m.HorizDistance, 0)) AS TotalHorizontalDistance,
    SUM(ISNULL(m.VertDistance, 0)) AS TotalVerticalDistance,
    
    -- Quality Metrics
    SUM(ISNULL(m.NrErrors, 0)) AS TotalErrors,
    
    -- Calculated Metrics
    CASE 
        WHEN SUM(ISNULL(m.TimeSpent, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0)
        ELSE 0 
    END AS AvgPicksPerTimeUnit,
    
    CASE 
        WHEN SUM(ISNULL(m.QttPicked, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.NrErrors, 0)) AS DECIMAL(18,4)) / NULLIF(SUM(m.QttPicked), 0) * 100
        ELSE 0 
    END AS ErrorRatePercent,
    
    COUNT(DISTINCT m.[Date]) AS DaysWorked
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
    LEFT JOIN dbo.TM_USERS u ON m.Oprt = u.Operator
    LEFT JOIN dbo.TM_EQUIPA e ON m.Team = e.Team
GROUP BY 
    YEAR(m.[Date]),
    DATEPART(ISO_WEEK, m.[Date]),
    m.Oprt,
    u.Name,
    m.Team,
    e.Name
GO

-- =============================================
-- View 3: Team Performance Dashboard
-- =============================================
-- Description: Team-level productivity metrics
-- Usage: SELECT * FROM vw_TeamPerformance WHERE Date >= '2025-01-01'
-- =============================================

IF OBJECT_ID('dbo.vw_TeamPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TeamPerformance
GO

CREATE VIEW dbo.vw_TeamPerformance
AS
SELECT 
    m.[Date],
    DATENAME(weekday, m.[Date]) AS DayOfWeek,
    m.Team,
    e.Name AS TeamName,
    e.Squadra,
    e.Director,
    m.Shift,
    
    -- Operators Count
    COUNT(DISTINCT m.Oprt) AS NumberOfOperators,
    
    -- Aggregated Quantities
    SUM(ISNULL(m.QttPicked, 0)) AS TotalQtyPicked,
    SUM(ISNULL(m.QttChecked, 0)) AS TotalQtyChecked,
    SUM(ISNULL(m.QttCounted, 0)) AS TotalQtyCounted,
    
    -- Aggregated Time
    SUM(ISNULL(m.TimeSpent, 0)) AS TotalTimeSpent,
    
    -- Aggregated Activities
    SUM(ISNULL(m.NrActions, 0)) AS TotalActions,
    SUM(ISNULL(m.NrContainers, 0)) AS TotalContainers,
    SUM(ISNULL(m.Numero_linee, 0)) AS TotalLines,
    
    -- Quality Metrics
    SUM(ISNULL(m.NrErrors, 0)) AS TotalErrors,
    
    -- Performance Metrics
    CASE 
        WHEN SUM(ISNULL(m.TimeSpent, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0)
        ELSE 0 
    END AS AvgPicksPerTimeUnit,
    
    CASE 
        WHEN SUM(ISNULL(m.QttPicked, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.NrErrors, 0)) AS DECIMAL(18,4)) / NULLIF(SUM(m.QttPicked), 0) * 100
        ELSE 0 
    END AS ErrorRatePercent,
    
    -- Per Operator Averages
    CASE 
        WHEN COUNT(DISTINCT m.Oprt) > 0 THEN 
            CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(COUNT(DISTINCT m.Oprt), 0)
        ELSE 0 
    END AS AvgQtyPickedPerOperator,
    
    MAX(m.RetrievedAt) AS LastUpdated
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
    LEFT JOIN dbo.TM_EQUIPA e ON m.Team = e.Team
GROUP BY 
    m.[Date],
    DATENAME(weekday, m.[Date]),
    m.Team,
    e.Name,
    e.Squadra,
    e.Director,
    m.Shift
GO

-- =============================================
-- View 4: Work Type Analysis
-- =============================================
-- Description: Productivity breakdown by work type
-- Usage: SELECT * FROM vw_WorkTypeAnalysis WHERE Date >= '2025-01-01'
-- =============================================

IF OBJECT_ID('dbo.vw_WorkTypeAnalysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_WorkTypeAnalysis
GO

CREATE VIEW dbo.vw_WorkTypeAnalysis
AS
SELECT 
    m.[Date],
    DATENAME(weekday, m.[Date]) AS DayOfWeek,
    m.WrkType AS WorkTypeCode,
    w.Name AS WorkTypeName,
    w.Description AS WorkTypeDescription,
    w.GrpCode AS WorkTypeGroup,
    
    -- Volume Metrics
    COUNT(DISTINCT m.Oprt) AS NumberOfOperators,
    SUM(ISNULL(m.QttPicked, 0)) AS TotalQtyPicked,
    SUM(ISNULL(m.QttChecked, 0)) AS TotalQtyChecked,
    SUM(ISNULL(m.QttCounted, 0)) AS TotalQtyCounted,
    
    -- Time Metrics
    SUM(ISNULL(m.TimeSpent, 0)) AS TotalTimeSpent,
    
    -- Activity Metrics
    SUM(ISNULL(m.NrActions, 0)) AS TotalActions,
    SUM(ISNULL(m.NrContainers, 0)) AS TotalContainers,
    SUM(ISNULL(m.Numero_linee, 0)) AS TotalLines,
    
    -- Distance Metrics
    SUM(ISNULL(m.HorizDistance, 0)) AS TotalHorizontalDistance,
    SUM(ISNULL(m.VertDistance, 0)) AS TotalVerticalDistance,
    
    -- Quality Metrics
    SUM(ISNULL(m.NrErrors, 0)) AS TotalErrors,
    
    -- Efficiency Metrics
    CASE 
        WHEN SUM(ISNULL(m.TimeSpent, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0)
        ELSE 0 
    END AS PicksPerTimeUnit,
    
    CASE 
        WHEN SUM(ISNULL(m.QttPicked, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.NrErrors, 0)) AS DECIMAL(18,4)) / NULLIF(SUM(m.QttPicked), 0) * 100
        ELSE 0 
    END AS ErrorRatePercent,
    
    MAX(m.RetrievedAt) AS LastUpdated
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
    LEFT JOIN dbo.TM_UDT w ON m.WrkType = w.WrkType
GROUP BY 
    m.[Date],
    DATENAME(weekday, m.[Date]),
    m.WrkType,
    w.Name,
    w.Description,
    w.GrpCode
GO

-- =============================================
-- View 5: Operator Performance Ranking
-- =============================================
-- Description: Ranks operators by various performance metrics
-- Usage: SELECT * FROM vw_OperatorPerformanceRanking WHERE Date >= '2025-01-01'
-- =============================================

IF OBJECT_ID('dbo.vw_OperatorPerformanceRanking', 'V') IS NOT NULL
    DROP VIEW dbo.vw_OperatorPerformanceRanking
GO

CREATE VIEW dbo.vw_OperatorPerformanceRanking
AS
WITH OperatorMetrics AS (
    SELECT 
        m.Oprt AS OperatorCode,
        u.Name AS OperatorName,
        u.Profile AS OperatorProfile,
        m.Team,
        e.Name AS TeamName,
        SUM(ISNULL(m.QttPicked, 0)) AS TotalQtyPicked,
        SUM(ISNULL(m.QttChecked, 0)) AS TotalQtyChecked,
        SUM(ISNULL(m.TimeSpent, 0)) AS TotalTimeSpent,
        SUM(ISNULL(m.NrErrors, 0)) AS TotalErrors,
        SUM(ISNULL(m.NrActions, 0)) AS TotalActions,
        COUNT(DISTINCT m.[Date]) AS DaysWorked,
        CASE 
            WHEN SUM(ISNULL(m.TimeSpent, 0)) > 0 THEN 
                CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0)
            ELSE 0 
        END AS PicksPerTimeUnit,
        CASE 
            WHEN SUM(ISNULL(m.QttPicked, 0)) > 0 THEN 
                CAST(SUM(ISNULL(m.NrErrors, 0)) AS DECIMAL(18,4)) / NULLIF(SUM(m.QttPicked), 0) * 100
            ELSE 0 
        END AS ErrorRatePercent
    FROM 
        dbo.MOV_ESTAT_PRODUTIVIDADE m
        LEFT JOIN dbo.TM_USERS u ON m.Oprt = u.Operator
        LEFT JOIN dbo.TM_EQUIPA e ON m.Team = e.Team
    GROUP BY 
        m.Oprt,
        u.Name,
        u.Profile,
        m.Team,
        e.Name
)
SELECT 
    OperatorCode,
    OperatorName,
    OperatorProfile,
    Team,
    TeamName,
    TotalQtyPicked,
    TotalQtyChecked,
    TotalTimeSpent,
    TotalErrors,
    TotalActions,
    DaysWorked,
    PicksPerTimeUnit,
    ErrorRatePercent,
    
    -- Rankings
    RANK() OVER (ORDER BY TotalQtyPicked DESC) AS RankByTotalPicked,
    RANK() OVER (ORDER BY PicksPerTimeUnit DESC) AS RankByEfficiency,
    RANK() OVER (ORDER BY ErrorRatePercent ASC) AS RankByQuality,
    RANK() OVER (ORDER BY TotalActions DESC) AS RankByActions,
    
    -- Percentiles
    PERCENT_RANK() OVER (ORDER BY PicksPerTimeUnit) AS EfficiencyPercentile,
    PERCENT_RANK() OVER (ORDER BY ErrorRatePercent DESC) AS QualityPercentile
FROM 
    OperatorMetrics
WHERE 
    DaysWorked >= 5  -- Only include operators with at least 5 days of work
GO

-- =============================================
-- View 6: Monthly Productivity Trends
-- =============================================
-- Description: Monthly aggregation for trend analysis
-- Usage: SELECT * FROM vw_MonthlyProductivityTrends ORDER BY Year, Month
-- =============================================

IF OBJECT_ID('dbo.vw_MonthlyProductivityTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_MonthlyProductivityTrends
GO

CREATE VIEW dbo.vw_MonthlyProductivityTrends
AS
SELECT 
    YEAR(m.[Date]) AS [Year],
    MONTH(m.[Date]) AS [Month],
    DATENAME(MONTH, m.[Date]) AS MonthName,
    MIN(m.[Date]) AS MonthStartDate,
    MAX(m.[Date]) AS MonthEndDate,
    
    -- Volume Metrics
    COUNT(DISTINCT m.Oprt) AS UniqueOperators,
    COUNT(DISTINCT m.[Date]) AS WorkingDays,
    SUM(ISNULL(m.QttPicked, 0)) AS TotalQtyPicked,
    SUM(ISNULL(m.QttChecked, 0)) AS TotalQtyChecked,
    SUM(ISNULL(m.QttCounted, 0)) AS TotalQtyCounted,
    
    -- Time Metrics
    SUM(ISNULL(m.TimeSpent, 0)) AS TotalTimeSpent,
    
    -- Activity Metrics
    SUM(ISNULL(m.NrActions, 0)) AS TotalActions,
    SUM(ISNULL(m.NrContainers, 0)) AS TotalContainers,
    SUM(ISNULL(m.Numero_linee, 0)) AS TotalLines,
    
    -- Distance Metrics
    SUM(ISNULL(m.HorizDistance, 0)) AS TotalHorizontalDistance,
    SUM(ISNULL(m.VertDistance, 0)) AS TotalVerticalDistance,
    
    -- Quality Metrics
    SUM(ISNULL(m.NrErrors, 0)) AS TotalErrors,
    
    -- Average Daily Metrics
    AVG(CAST(ISNULL(m.QttPicked, 0) AS DECIMAL(18,2))) AS AvgDailyQtyPicked,
    AVG(CAST(ISNULL(m.TimeSpent, 0) AS DECIMAL(18,2))) AS AvgDailyTimeSpent,
    
    -- Performance Metrics
    CASE 
        WHEN SUM(ISNULL(m.TimeSpent, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.QttPicked, 0)) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0)
        ELSE 0 
    END AS OverallPicksPerTimeUnit,
    
    CASE 
        WHEN SUM(ISNULL(m.QttPicked, 0)) > 0 THEN 
            CAST(SUM(ISNULL(m.NrErrors, 0)) AS DECIMAL(18,4)) / NULLIF(SUM(m.QttPicked), 0) * 100
        ELSE 0 
    END AS OverallErrorRatePercent
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
GROUP BY 
    YEAR(m.[Date]),
    MONTH(m.[Date]),
    DATENAME(MONTH, m.[Date])
GO

-- =============================================
-- View 7: Error Analysis
-- =============================================
-- Description: Detailed error analysis by operator and work type
-- Usage: SELECT * FROM vw_ErrorAnalysis WHERE TotalErrors > 0
-- =============================================

IF OBJECT_ID('dbo.vw_ErrorAnalysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ErrorAnalysis
GO

CREATE VIEW dbo.vw_ErrorAnalysis
AS
SELECT 
    m.[Date],
    DATENAME(weekday, m.[Date]) AS DayOfWeek,
    m.Oprt AS OperatorCode,
    u.Name AS OperatorName,
    u.Profile AS OperatorProfile,
    m.Team,
    e.Name AS TeamName,
    m.WrkType AS WorkTypeCode,
    w.Name AS WorkTypeName,
    m.Shift,
    
    -- Quantities
    ISNULL(m.QttPicked, 0) AS QtyPicked,
    ISNULL(m.QttChecked, 0) AS QtyChecked,
    
    -- Errors
    ISNULL(m.NrErrors, 0) AS TotalErrors,
    ISNULL(m.DifQtt, 0) AS DifferenceQty,
    ISNULL(m.DiffQtt2, 0) AS DifferenceQty2,
    
    -- Error Rate
    CASE 
        WHEN ISNULL(m.QttPicked, 0) > 0 THEN 
            CAST(ISNULL(m.NrErrors, 0) AS DECIMAL(18,4)) / NULLIF(m.QttPicked, 0) * 100
        ELSE 0 
    END AS ErrorRatePercent,
    
    -- Classification
    CASE 
        WHEN ISNULL(m.NrErrors, 0) = 0 THEN 'No Errors'
        WHEN CAST(ISNULL(m.NrErrors, 0) AS DECIMAL) / NULLIF(m.QttPicked, 0) * 100 < 1 THEN 'Low (<1%)'
        WHEN CAST(ISNULL(m.NrErrors, 0) AS DECIMAL) / NULLIF(m.QttPicked, 0) * 100 < 3 THEN 'Medium (1-3%)'
        ELSE 'High (>3%)'
    END AS ErrorCategory,
    
    m.RetrievedAt AS LastUpdated
FROM 
    dbo.MOV_ESTAT_PRODUTIVIDADE m
    LEFT JOIN dbo.TM_USERS u ON m.Oprt = u.Operator
    LEFT JOIN dbo.TM_EQUIPA e ON m.Team = e.Team
    LEFT JOIN dbo.TM_UDT w ON m.WrkType = w.WrkType
WHERE 
    ISNULL(m.NrErrors, 0) > 0  -- Only show records with errors
GO

-- =============================================
-- Grant permissions (adjust as needed)
-- =============================================

GRANT SELECT ON dbo.vw_DailyProductivityByOperator TO PUBLIC
GRANT SELECT ON dbo.vw_WeeklyProductivitySummary TO PUBLIC
GRANT SELECT ON dbo.vw_TeamPerformance TO PUBLIC
GRANT SELECT ON dbo.vw_WorkTypeAnalysis TO PUBLIC
GRANT SELECT ON dbo.vw_OperatorPerformanceRanking TO PUBLIC
GRANT SELECT ON dbo.vw_MonthlyProductivityTrends TO PUBLIC
GRANT SELECT ON dbo.vw_ErrorAnalysis TO PUBLIC
GO

PRINT 'All reporting views created successfully!'
GO
