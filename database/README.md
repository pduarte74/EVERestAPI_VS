# Database SQL Scripts

This directory contains SQL scripts for creating reporting views and sample queries for the WPMS API Integration solution.

## Files

### 01_Create_Reporting_Views.sql
Creates 7 comprehensive SQL views for reporting and analysis:

1. **vw_DailyProductivityByOperator** - Daily metrics per operator with calculated KPIs
2. **vw_WeeklyProductivitySummary** - Weekly aggregation by operator
3. **vw_TeamPerformance** - Team-level performance dashboard
4. **vw_WorkTypeAnalysis** - Productivity breakdown by work type
5. **vw_OperatorPerformanceRanking** - Operator rankings and percentiles
6. **vw_MonthlyProductivityTrends** - Monthly trends for time series analysis
7. **vw_ErrorAnalysis** - Detailed error tracking and categorization

### 02_Sample_Queries.sql
Example queries demonstrating how to use the views for common reporting scenarios.

## Installation

```sql
-- Run in SQL Server Management Studio or Azure Data Studio
-- Connected to EVEReporting database

-- Step 1: Create the views
:r 01_Create_Reporting_Views.sql

-- Step 2: Test with sample queries
:r 02_Sample_Queries.sql
```

Or execute manually:
1. Open SQL Server Management Studio
2. Connect to your SQL Server instance
3. Open `01_Create_Reporting_Views.sql`
4. Execute (F5)
5. Verify all views created successfully

## View Descriptions

### vw_DailyProductivityByOperator
**Purpose:** Detailed daily productivity for each operator
**Key Fields:**
- Date, Operator info, Work type
- Quantities (picked, checked, counted)
- Time spent, actions, containers
- Distance traveled (horizontal/vertical)
- Errors and quality metrics
- Calculated: Picks per time unit, Error rate %

**Example Usage:**
```sql
-- Get last 7 days for specific operator
SELECT * 
FROM vw_DailyProductivityByOperator 
WHERE OperatorCode = 'OP123' 
  AND Date >= DATEADD(day, -7, GETDATE())
ORDER BY Date DESC
```

### vw_WeeklyProductivitySummary
**Purpose:** Weekly aggregated metrics by operator
**Key Fields:**
- Year, Week number, Week date range
- Operator and team info
- Aggregated totals (qty, time, activities)
- Average efficiency metrics
- Days worked in week

**Example Usage:**
```sql
-- Compare operators in current week
SELECT TOP 10 *
FROM vw_WeeklyProductivitySummary
WHERE Year = YEAR(GETDATE())
  AND WeekNumber = DATEPART(ISO_WEEK, GETDATE())
ORDER BY TotalQtyPicked DESC
```

### vw_TeamPerformance
**Purpose:** Team-level daily performance metrics
**Key Fields:**
- Date, Team info
- Number of operators
- Aggregated team totals
- Average performance metrics
- Per-operator averages

**Example Usage:**
```sql
-- Team comparison for current month
SELECT Team, TeamName, 
       SUM(TotalQtyPicked) AS MonthlyPicks,
       AVG(ErrorRatePercent) AS AvgErrorRate
FROM vw_TeamPerformance
WHERE Date >= DATEADD(month, -1, GETDATE())
GROUP BY Team, TeamName
ORDER BY MonthlyPicks DESC
```

### vw_WorkTypeAnalysis
**Purpose:** Productivity analysis by type of work
**Key Fields:**
- Date, Work type info
- Number of operators
- Aggregated volumes and metrics
- Efficiency by work type
- Distance metrics

**Example Usage:**
```sql
-- Most common work types
SELECT WorkTypeName, 
       COUNT(*) AS Occurrences,
       SUM(TotalQtyPicked) AS TotalPicked,
       AVG(PicksPerTimeUnit) AS AvgEfficiency
FROM vw_WorkTypeAnalysis
WHERE Date >= '2025-01-01'
GROUP BY WorkTypeName
ORDER BY TotalPicked DESC
```

### vw_OperatorPerformanceRanking
**Purpose:** Operator comparison and rankings
**Key Fields:**
- Operator info with totals
- Days worked
- Performance metrics
- Rankings (by volume, efficiency, quality)
- Percentiles for benchmarking

**Example Usage:**
```sql
-- Top 10 performers by efficiency
SELECT TOP 10 
    OperatorName,
    PicksPerTimeUnit,
    ErrorRatePercent,
    RankByEfficiency,
    EfficiencyPercentile
FROM vw_OperatorPerformanceRanking
ORDER BY RankByEfficiency
```

### vw_MonthlyProductivityTrends
**Purpose:** Monthly trends for time series analysis
**Key Fields:**
- Year, Month, date range
- Unique operators, working days
- Aggregated monthly totals
- Average daily metrics
- Overall performance indicators

**Example Usage:**
```sql
-- Year-over-year comparison
SELECT Year, Month, MonthName,
       TotalQtyPicked,
       OverallPicksPerTimeUnit,
       OverallErrorRatePercent
FROM vw_MonthlyProductivityTrends
ORDER BY Year, Month
```

### vw_ErrorAnalysis
**Purpose:** Detailed error tracking and investigation
**Key Fields:**
- Date, Operator, Team, Work type
- Quantities processed
- Error counts and differences
- Error rate percentage
- Error category (Low/Medium/High)

**Example Usage:**
```sql
-- Operators with high error rates
SELECT OperatorName, 
       COUNT(*) AS DaysWithErrors,
       SUM(TotalErrors) AS TotalErrors,
       AVG(ErrorRatePercent) AS AvgErrorRate
FROM vw_ErrorAnalysis
WHERE Date >= DATEADD(month, -1, GETDATE())
GROUP BY OperatorName
HAVING AVG(ErrorRatePercent) > 2.0
ORDER BY AvgErrorRate DESC
```

## Common Reporting Scenarios

### 1. Daily Operations Dashboard
```sql
SELECT * FROM vw_TeamPerformance 
WHERE Date = CAST(GETDATE() AS DATE)
ORDER BY TotalQtyPicked DESC
```

### 2. Weekly Performance Review
```sql
SELECT * FROM vw_WeeklyProductivitySummary
WHERE Year = YEAR(GETDATE())
  AND WeekNumber = DATEPART(ISO_WEEK, GETDATE())
ORDER BY TotalQtyPicked DESC
```

### 3. Monthly Management Report
```sql
SELECT * FROM vw_MonthlyProductivityTrends
WHERE Year = YEAR(GETDATE())
ORDER BY Month DESC
```

### 4. Operator Performance Review
```sql
SELECT * FROM vw_OperatorPerformanceRanking
WHERE DaysWorked >= 10
ORDER BY RankByEfficiency
```

### 5. Quality Control Report
```sql
SELECT * FROM vw_ErrorAnalysis
WHERE Date >= DATEADD(day, -30, GETDATE())
  AND ErrorCategory IN ('Medium (1-3%)', 'High (>3%)')
ORDER BY ErrorRatePercent DESC
```

## Excel Integration

These views are designed to be easily consumed by Excel:

1. **Excel → Data → Get Data → From SQL Server**
2. Enter server and database (EVEReporting)
3. Select desired view
4. Load to Excel or Power Query
5. Create PivotTables, charts, dashboards

## Performance Considerations

- Views use `LEFT JOIN` to handle missing reference data
- Pre-calculated metrics avoid complex calculations in reports
- Filtering by date is recommended for large datasets
- Consider adding indexes on base tables:
  ```sql
  CREATE INDEX IX_MOV_ESTAT_Date ON dbo.MOV_ESTAT_PRODUTIVIDADE(Date)
  CREATE INDEX IX_MOV_ESTAT_Oprt ON dbo.MOV_ESTAT_PRODUTIVIDADE(Oprt)
  CREATE INDEX IX_MOV_ESTAT_Team ON dbo.MOV_ESTAT_PRODUTIVIDADE(Team)
  ```

## Maintenance

Views are automatically updated when base table data changes. No maintenance required.

To refresh view definitions after schema changes:
```sql
-- Drop and recreate all views
:r 01_Create_Reporting_Views.sql
```

## Support

For issues or enhancements, contact: pedro.duarte@prodout.com
