USE [BANK_TEST]
GO
/****** Object:  StoredProcedure [dbo].[usp_Sumary_Currency]    Script Date: 9/19/2024 2:48:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_Sumary_Currency]
AS 
--Use SQL query to create currency summary as structured below
IF OBJECT_ID('Tempdb..#CurrencySummary') IS NOT NULL DROP TABLE #CurrencySummary
SELECT a.CurrencyCode, b.CurrencyName, a.VND AS OpeningBalance, CAST(0 AS NUMERIC(15,3)) AS Purchase, CAST(0 AS NUMERIC(15,3)) AS Sale
	INTO #CurrencySummary
	FROM CurOpen a
	LEFT JOIN Currency b ON a.CurrencyCode = b.CurrencyCode
UNION ALL
SELECT a.CurrencyCode, b.CurrencyName, CAST(0 AS NUMERIC(15,3)) AS OpeningBalance,
		CASE WHEN Tb3.DocGroup = 1 THEN a.VND ELSE CAST(0 AS NUMERIC(15,3)) END AS Purchase,
		CASE WHEN Tb3.DocGroup = 2 THEN a.VND ELSE CAST(0 AS NUMERIC(15,3)) END AS Sale
FROM CurDocDetail a
	LEFT JOIN Currency b ON a.CurrencyCode = b.CurrencyCode
	INNER JOIN CurDoc Tb3 ON a.DocNo = Tb3.DocNo

SELECT	CurrencyCode AS 'Currency Code',
		MAX(CurrencyName) AS 'Currency Name',
		SUM(OpeningBalance) AS 'Opening Balance',
		SUM(Purchase) AS 'Total Purchase',
		SUM(Sale) AS 'Total Sale',
		SUM(OpeningBalance) + SUM(Purchase) - SUM(Sale) AS 'Remaining Balance'
FROM #CurrencySummary
GROUP BY CurrencyCode  
UNION ALL
SELECT	'' AS CurrencyCode, 
		'Total' AS CurrencyName, 
		SUM(OpeningBalance), 
		SUM(Purchase), 
		SUM(Sale), 
		SUM(OpeningBalance) + SUM(Purchase) - SUM(Sale)
FROM #CurrencySummary

DROP TABLE #CurrencySummary

