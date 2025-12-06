-- =============================================
-- WPMS API Integration - Sample Queries
-- =============================================
-- Description: Example queries demonstrating view usage
-- Database: EVEReporting
-- Author: Pedro Duarte
-- Date: 2025-12-06
-- =============================================

USE [EVEReporting]
GO

-- =============================================
-- SCENARIO 1: Daily Operations Dashboard
-- =============================================
PRINT '=== Daily Operations Dashboard ==='
GO

-- Today's team performance summary
SELECT 
    Team,
    TeamName,
    NumberOfOperators,
    TotalQtyPicked,
    TotalQtyChecked,
    TotalErrors,
    ErrorRatePercent,
    AvgQtyPickedPerOperator
FROM vw_TeamPerformance
WHERE Date = CAST(GETDATE() AS DATE)
ORDER BY TotalQtyPicked DESC
GO

-- Today's top 10 performers
SELECT TOP 10
    OperatorName,
    QtyPicked,
    TimeSpent,
    PicksPerTimeUnit,
    NumberOfErrors,
    ErrorRatePercent
FROM vw_DailyProductivityByOperator
WHERE Date = CAST(GETDATE() AS DATE)
  AND QtyPicked > 0
ORDER BY PicksPerTimeUnit DESC
GO

-- =============================================
-- SCENARIO 2: Weekly Performance Review
-- =============================================
PRINT '=== Weekly Performance Review ==='
GO

-- Current week summary by operator
SELECT 
    OperatorName,
    TeamName,
    TotalQtyPicked,
    TotalTimeSpent,
    AvgPicksPerTimeUnit,
    ErrorRatePercent,
    DaysWorked
FROM vw_WeeklyProductivitySummary
WHERE Year = YEAR(GETDATE())
  AND WeekNumber = DATEPART(ISO_WEEK, GETDATE())
ORDER BY AvgPicksPerTimeUnit DESC
GO

-- Week-over-week comparison (current vs previous)
WITH CurrentWeek AS (
    SELECT 
        SUM(TotalQtyPicked) AS QtyPicked,
        SUM(TotalTimeSpent) AS TimeSpent,
        AVG(AvgPicksPerTimeUnit) AS AvgEfficiency
    FROM vw_WeeklyProductivitySummary
    WHERE Year = YEAR(GETDATE())
      AND WeekNumber = DATEPART(ISO_WEEK, GETDATE())
),
PreviousWeek AS (
    SELECT 
        SUM(TotalQtyPicked) AS QtyPicked,
        SUM(TotalTimeSpent) AS TimeSpent,
        AVG(AvgPicksPerTimeUnit) AS AvgEfficiency
    FROM vw_WeeklyProductivitySummary
    WHERE Year = YEAR(GETDATE())
      AND WeekNumber = DATEPART(ISO_WEEK, DATEADD(week, -1, GETDATE()))
)
SELECT 
    'Current Week' AS Period,
    cw.QtyPicked,
    cw.TimeSpent,
    cw.AvgEfficiency,
    CAST((cw.QtyPicked - pw.QtyPicked) AS DECIMAL(18,2)) / NULLIF(pw.QtyPicked, 0) * 100 AS QtyChangePercent,
    CAST((cw.AvgEfficiency - pw.AvgEfficiency) AS DECIMAL(18,2)) / NULLIF(pw.AvgEfficiency, 0) * 100 AS EfficiencyChangePercent
FROM CurrentWeek cw
CROSS JOIN PreviousWeek pw
GO

-- =============================================
-- SCENARIO 3: Monthly Management Report
-- =============================================
PRINT '=== Monthly Management Report ==='
GO

-- Year-to-date monthly trends
SELECT 
    Year,
    Month,
    MonthName,
    UniqueOperators,
    WorkingDays,
    TotalQtyPicked,
    TotalActions,
    TotalErrors,
    OverallPicksPerTimeUnit,
    OverallErrorRatePercent,
    CAST(TotalQtyPicked AS DECIMAL(18,2)) / NULLIF(UniqueOperators * WorkingDays, 0) AS AvgPicksPerOperatorDay
FROM vw_MonthlyProductivityTrends
WHERE Year = YEAR(GETDATE())
ORDER BY Month
GO

-- Month-over-month growth
SELECT 
    Year,
    Month,
    MonthName,
    TotalQtyPicked,
    LAG(TotalQtyPicked) OVER (ORDER BY Year, Month) AS PreviousMonthQty,
    CAST((TotalQtyPicked - LAG(TotalQtyPicked) OVER (ORDER BY Year, Month)) AS DECIMAL(18,2)) / 
        NULLIF(LAG(TotalQtyPicked) OVER (ORDER BY Year, Month), 0) * 100 AS GrowthPercent
FROM vw_MonthlyProductivityTrends
WHERE Year >= YEAR(DATEADD(year, -1, GETDATE()))
ORDER BY Year, Month
GO

-- =============================================
-- SCENARIO 4: Operator Performance Analysis
-- =============================================
PRINT '=== Operator Performance Analysis ==='
GO

-- Top performers (balanced view)
SELECT TOP 20
    OperatorName,
    TeamName,
    TotalQtyPicked,
    PicksPerTimeUnit,
    ErrorRatePercent,
    DaysWorked,
    RankByTotalPicked,
    RankByEfficiency,
    RankByQuality,
    CAST((EfficiencyPercentile + QualityPercentile) / 2.0 * 100 AS DECIMAL(5,2)) AS OverallPercentile
FROM vw_OperatorPerformanceRanking
ORDER BY (EfficiencyPercentile + QualityPercentile) / 2.0 DESC
GO

-- Operators needing improvement
SELECT 
    OperatorName,
    TeamName,
    TotalQtyPicked,
    PicksPerTimeUnit,
    ErrorRatePercent,
    DaysWorked,
    RankByEfficiency,
    CAST(EfficiencyPercentile * 100 AS DECIMAL(5,2)) AS EfficiencyPercentile
FROM vw_OperatorPerformanceRanking
WHERE EfficiencyPercentile < 0.25  -- Bottom 25%
   OR ErrorRatePercent > 2.0       -- Error rate > 2%
ORDER BY EfficiencyPercentile
GO

-- =============================================
-- SCENARIO 5: Quality Control & Error Analysis
-- =============================================
PRINT '=== Quality Control & Error Analysis ==='
GO

-- Daily error summary (last 30 days)
SELECT 
    Date,
    COUNT(DISTINCT OperatorCode) AS OperatorsWithErrors,
    SUM(TotalErrors) AS DailyErrors,
    SUM(QtyPicked) AS DailyQtyPicked,
    CAST(SUM(TotalErrors) AS DECIMAL(18,4)) / NULLIF(SUM(QtyPicked), 0) * 100 AS DailyErrorRate
FROM vw_ErrorAnalysis
WHERE Date >= DATEADD(day, -30, GETDATE())
GROUP BY Date
ORDER BY Date DESC
GO

-- Operators with highest error rates (last 30 days)
SELECT TOP 10
    OperatorName,
    TeamName,
    COUNT(*) AS DaysWithErrors,
    SUM(TotalErrors) AS TotalErrors,
    SUM(QtyPicked) AS TotalQtyPicked,
    AVG(ErrorRatePercent) AS AvgErrorRate,
    MAX(ErrorRatePercent) AS MaxErrorRate
FROM vw_ErrorAnalysis
WHERE Date >= DATEADD(day, -30, GETDATE())
GROUP BY OperatorName, TeamName
ORDER BY AvgErrorRate DESC
GO

-- Error breakdown by work type
SELECT 
    WorkTypeName,
    COUNT(DISTINCT Date) AS DaysWithErrors,
    COUNT(DISTINCT OperatorCode) AS OperatorsAffected,
    SUM(TotalErrors) AS TotalErrors,
    AVG(ErrorRatePercent) AS AvgErrorRate
FROM vw_ErrorAnalysis
WHERE Date >= DATEADD(month, -1, GETDATE())
GROUP BY WorkTypeName
ORDER BY TotalErrors DESC
GO

-- =============================================
-- SCENARIO 6: Work Type Efficiency Comparison
-- =============================================
PRINT '=== Work Type Efficiency Comparison ==='
GO

-- Average efficiency by work type (last 30 days)
SELECT 
    WorkTypeName,
    WorkTypeDescription,
    COUNT(*) AS Occurrences,
    SUM(NumberOfOperators) AS TotalOperators,
    SUM(TotalQtyPicked) AS TotalQtyPicked,
    SUM(TotalTimeSpent) AS TotalTimeSpent,
    AVG(PicksPerTimeUnit) AS AvgPicksPerTimeUnit,
    AVG(ErrorRatePercent) AS AvgErrorRate,
    SUM(TotalHorizontalDistance) AS TotalDistanceTraveled
FROM vw_WorkTypeAnalysis
WHERE Date >= DATEADD(day, -30, GETDATE())
GROUP BY WorkTypeName, WorkTypeDescription
ORDER BY TotalQtyPicked DESC
GO

-- Most/Least efficient work types
WITH WorkTypeEfficiency AS (
    SELECT 
        WorkTypeName,
        AVG(PicksPerTimeUnit) AS AvgEfficiency,
        COUNT(*) AS SampleSize
    FROM vw_WorkTypeAnalysis
    WHERE Date >= DATEADD(month, -1, GETDATE())
      AND TotalQtyPicked > 0
    GROUP BY WorkTypeName
    HAVING COUNT(*) >= 5  -- At least 5 days of data
)
SELECT 
    'Most Efficient' AS Category,
    WorkTypeName,
    AvgEfficiency,
    SampleSize
FROM WorkTypeEfficiency
WHERE AvgEfficiency = (SELECT MAX(AvgEfficiency) FROM WorkTypeEfficiency)
UNION ALL
SELECT 
    'Least Efficient' AS Category,
    WorkTypeName,
    AvgEfficiency,
    SampleSize
FROM WorkTypeEfficiency
WHERE AvgEfficiency = (SELECT MIN(AvgEfficiency) FROM WorkTypeEfficiency)
GO

-- =============================================
-- SCENARIO 7: Team Comparison & Benchmarking
-- =============================================
PRINT '=== Team Comparison & Benchmarking ==='
GO

-- Team performance comparison (current month)
SELECT 
    Team,
    TeamName,
    COUNT(DISTINCT Date) AS DaysActive,
    AVG(NumberOfOperators) AS AvgOperatorsPerDay,
    SUM(TotalQtyPicked) AS MonthlyQtyPicked,
    SUM(TotalErrors) AS MonthlyErrors,
    AVG(AvgPicksPerTimeUnit) AS AvgEfficiency,
    AVG(ErrorRatePercent) AS AvgErrorRate,
    SUM(TotalQtyPicked) / NULLIF(SUM(TotalErrors), 0) AS PicksPerError
FROM vw_TeamPerformance
WHERE Date >= DATEADD(month, -1, GETDATE())
GROUP BY Team, TeamName
ORDER BY AvgEfficiency DESC
GO

-- Team consistency analysis
SELECT 
    Team,
    TeamName,
    COUNT(DISTINCT Date) AS DaysActive,
    AVG(TotalQtyPicked) AS AvgDailyQty,
    STDEV(TotalQtyPicked) AS StdDevDailyQty,
    MIN(TotalQtyPicked) AS MinDailyQty,
    MAX(TotalQtyPicked) AS MaxDailyQty,
    CAST(STDEV(TotalQtyPicked) / NULLIF(AVG(TotalQtyPicked), 0) * 100 AS DECIMAL(5,2)) AS CoefficientOfVariation
FROM vw_TeamPerformance
WHERE Date >= DATEADD(month, -1, GETDATE())
GROUP BY Team, TeamName
ORDER BY CoefficientOfVariation
GO

-- =============================================
-- SCENARIO 8: Trend Analysis & Forecasting Data
-- =============================================
PRINT '=== Trend Analysis & Forecasting Data ==='
GO

-- Daily productivity trends (last 60 days)
SELECT 
    Date,
    DATENAME(weekday, Date) AS DayOfWeek,
    SUM(QtyPicked) AS DailyQtyPicked,
    COUNT(DISTINCT Oprt) AS ActiveOperators,
    AVG(PicksPerTimeUnit) AS AvgEfficiency,
    AVG(ErrorRatePercent) AS AvgErrorRate,
    AVG(SUM(QtyPicked)) OVER (ORDER BY Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS SevenDayMovingAvg
FROM vw_DailyProductivityByOperator
WHERE Date >= DATEADD(day, -60, GETDATE())
GROUP BY Date
ORDER BY Date
GO

-- Day of week patterns
SELECT 
    DATENAME(weekday, Date) AS DayOfWeek,
    DATEPART(weekday, Date) AS DayNumber,
    COUNT(DISTINCT Date) AS Occurrences,
    AVG(QtyPicked) AS AvgQtyPicked,
    AVG(TimeSpent) AS AvgTimeSpent,
    AVG(PicksPerTimeUnit) AS AvgEfficiency,
    SUM(NumberOfErrors) AS TotalErrors
FROM vw_DailyProductivityByOperator
WHERE Date >= DATEADD(month, -3, GETDATE())
GROUP BY DATENAME(weekday, Date), DATEPART(weekday, Date)
ORDER BY DayNumber
GO

-- =============================================
-- SCENARIO 9: Operator Attendance & Activity
-- =============================================
PRINT '=== Operator Attendance & Activity ==='
GO

-- Operator attendance last 30 days
SELECT 
    OperatorCode,
    OperatorName,
    COUNT(DISTINCT Date) AS DaysWorked,
    COUNT(DISTINCT WrkType) AS DifferentWorkTypes,
    SUM(QtyPicked) AS TotalQtyPicked,
    AVG(PicksPerTimeUnit) AS AvgEfficiency,
    MIN(Date) AS FirstWorkDate,
    MAX(Date) AS LastWorkDate
FROM vw_DailyProductivityByOperator
WHERE Date >= DATEADD(day, -30, GETDATE())
GROUP BY OperatorCode, OperatorName
ORDER BY DaysWorked DESC, TotalQtyPicked DESC
GO

-- =============================================
-- SCENARIO 10: Executive Summary (KPIs)
-- =============================================
PRINT '=== Executive Summary (KPIs) ==='
GO

-- High-level KPIs for current month
DECLARE @CurrentMonth DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)

SELECT 
    'Current Month KPIs' AS Report,
    COUNT(DISTINCT m.Oprt) AS ActiveOperators,
    COUNT(DISTINCT m.Date) AS WorkingDays,
    SUM(m.QtyPicked) AS TotalQtyPicked,
    SUM(m.TimeSpent) AS TotalHoursWorked,
    SUM(m.NrErrors) AS TotalErrors,
    CAST(SUM(m.QtyPicked) AS DECIMAL(18,2)) / NULLIF(SUM(m.TimeSpent), 0) AS OverallEfficiency,
    CAST(SUM(m.NrErrors) AS DECIMAL(18,4)) / NULLIF(SUM(m.QtyPicked), 0) * 100 AS OverallErrorRate,
    CAST(SUM(m.QtyPicked) AS DECIMAL(18,2)) / NULLIF(COUNT(DISTINCT m.Oprt), 0) AS AvgQtyPerOperator,
    CAST(SUM(m.QtyPicked) AS DECIMAL(18,2)) / NULLIF(COUNT(DISTINCT m.Date), 0) AS AvgQtyPerDay
FROM vw_DailyProductivityByOperator m
WHERE Date >= @CurrentMonth
GO

PRINT 'Sample queries completed successfully!'
GO
