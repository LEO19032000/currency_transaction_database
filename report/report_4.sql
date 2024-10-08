USE [BANK_TEST]
GO
/****** Object:  StoredProcedure [dbo].[usp_Detailed_Currency_Transactions]    Script Date: 9/19/2024 3:05:57 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_Detailed_Currency_Transactions]
AS
-- Requirement 5: Use SQL query to create detailed foreign currency transactions report

IF OBJECT_ID('tempdb..#Transactions0') IS NOT NULL DROP TABLE #Transactions0
-- Create table for Purchase/Sale transactions with opening balance
SELECT Tb2.CurrencyCode, Tb1.DocDate, Tb1.Description, 
		CASE WHEN Tb1.DocGroup = 1 THEN OriginalCurrency ELSE 0 END AS Purchase_Currency,
		CASE WHEN Tb1.DocGroup = 1 THEN VND ELSE 0 END AS Purchase_VND,
		CASE WHEN Tb1.DocGroup = 2 THEN OriginalCurrency ELSE 0 END AS Sale_Currency,
		CASE WHEN Tb1.DocGroup = 2 THEN VND ELSE 0 END AS Sale_VND,
		CAST(0 AS NUMERIC(15,3)) AS Remaining_Currency, CAST(0 AS NUMERIC(18,2)) AS Remaining_VND
	INTO #Transactions0 
	FROM CurDocDetail Tb2 JOIN CurDoc Tb1 ON Tb1.DocNo = Tb2.DocNo

IF OBJECT_ID('tempdb..#Transactions1') IS NOT NULL DROP TABLE #Transactions1
-- DENSE_RANK to rank by CurrencyCode
SELECT DENSE_RANK() OVER (ORDER BY Tb.CurrencyCode) AS [No], Tb.CurrencyCode, Tb.DocDate, Tb.Description, 
		Tb.Purchase_Currency, Tb.Purchase_VND, Tb.Sale_Currency, Tb.Sale_VND,
		SUM(Tb.Remaining_Currency + Tb.Purchase_Currency - Tb.Sale_Currency) OVER (PARTITION BY Tb.CurrencyCode ORDER BY Tb.DocDate) AS Remaining_Currency,
		SUM(Tb.Remaining_VND + Tb.Purchase_VND - Tb.Sale_VND) OVER (PARTITION BY Tb.CurrencyCode ORDER BY Tb.DocDate) AS Remaining_VND
	INTO #Transactions1
	FROM (SELECT CurrencyCode, DocDate, Description, Sale_Currency, Sale_VND, Purchase_Currency, Purchase_VND, Remaining_Currency, Remaining_VND 
			FROM #Transactions0
			UNION ALL
			SELECT DISTINCT Tb1.CurrencyCode, NULL, N'Opening Balance', 0, 0, 0, 0, ISNULL(Tb2.OriginalCurrency, 0), ISNULL(Tb2.VND, 0)
			FROM CurDocDetail Tb1 LEFT OUTER JOIN CurOpen Tb2 ON Tb1.CurrencyCode = Tb2.CurrencyCode) Tb

IF OBJECT_ID('tempdb..#SummaryTransactions') IS NOT NULL DROP TABLE #SummaryTransactions
-- Create summary of Purchase/Sale
SELECT 2 * ROW_NUMBER() OVER (ORDER BY CurrencyCode) AS [No], CurrencyCode, CAST(NULL AS datetime) AS DocDate, 
		N'Total Purchase/Sale' AS Description, 
		SUM(Purchase_Currency) AS Purchase_Currency, 
		SUM(Purchase_VND) AS Purchase_VND, 
		SUM(Sale_Currency) AS Sale_Currency, 
		SUM(Sale_VND) AS Sale_VND, 
		CAST(0 AS NUMERIC(15,3)) AS Remaining_Currency, 
		CAST(0 AS NUMERIC(18,2)) AS Remaining_VND
	INTO #SummaryTransactions
	FROM #Transactions0
	GROUP BY CurrencyCode
	ORDER BY CurrencyCode

IF OBJECT_ID('tempdb..#EndingBalance') IS NOT NULL DROP TABLE #EndingBalance
SELECT 3 * ROW_NUMBER() OVER (ORDER BY CurrencyCode) AS [No], Tb.CurrencyCode, Tb.DocDate, Tb.Description, 
		Tb.Purchase_Currency, Tb.Purchase_VND, Tb.Sale_Currency, Tb.Sale_VND, Tb.Remaining_Currency, Tb.Remaining_VND
	INTO #EndingBalance
	FROM (SELECT Tb1.CurrencyCode, CAST(NULL AS datetime) AS DocDate, N'Ending Balance' AS Description, 
			CAST(0 AS NUMERIC(15,3)) AS Purchase_Currency, CAST(0 AS NUMERIC(18,2)) AS Purchase_VND, 
			CAST(0 AS NUMERIC(15,3)) AS Sale_Currency, CAST(0 AS NUMERIC(18,2)) AS Sale_VND, 
			ISNULL(Tb2.OriginalCurrency, 0 ) + ISNULL(Tb1.Purchase_Currency, 0) - ISNULL(Tb1.Sale_Currency, 0) AS Remaining_Currency, 
			ISNULL(Tb2.VND, 0) + ISNULL(Tb1.Purchase_VND, 0) - ISNULL(Tb1.Sale_VND, 0) AS Remaining_VND
			FROM #SummaryTransactions Tb1 LEFT OUTER JOIN CurOpen Tb2 ON Tb1.CurrencyCode = Tb2.CurrencyCode) Tb

IF OBJECT_ID('tempdb..#Report') IS NOT NULL DROP TABLE #Report
SELECT RANK() OVER (ORDER BY Tb.CurrencyCode, Tb.No, Tb.DocDate) AS No, Tb.CurrencyCode, Tb.DocDate, 
	Tb.Description, Tb.Purchase_Currency, Tb.Purchase_VND, Tb.Sale_Currency, Tb.Sale_VND, Tb.Remaining_Currency, Tb.Remaining_VND
INTO #Report
FROM (SELECT No, CurrencyCode, DocDate, Description, Purchase_Currency, Purchase_VND, Sale_Currency, Sale_VND, Remaining_Currency, Remaining_VND FROM #Transactions1 
		UNION ALL 
	SELECT No, CurrencyCode, DocDate, Description, Purchase_Currency, Purchase_VND, Sale_Currency, Sale_VND, Remaining_Currency, Remaining_VND FROM #SummaryTransactions
		UNION ALL 
	SELECT No, CurrencyCode, DocDate, Description, Purchase_Currency, Purchase_VND, Sale_Currency, Sale_VND, Remaining_Currency, Remaining_VND FROM #EndingBalance) Tb

SELECT CurrencyCode AS 'Currency Code', ISNULL(CONVERT(VARCHAR, DocDate, 10), '') AS 'Date', Description AS 'Description', 
		CASE WHEN Purchase_Currency <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Purchase_Currency)) ELSE '' END AS 'Purchased Currency', 
		CASE WHEN Purchase_VND <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Purchase_VND)) ELSE '' END AS 'Purchased VND', 
		CASE WHEN Sale_Currency <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Sale_Currency)) ELSE '' END AS 'Sold Currency', 
		CASE WHEN Sale_VND <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Sale_VND)) ELSE '' END AS 'Sold VND', 
		CASE WHEN Remaining_Currency <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Remaining_Currency)) ELSE '' END AS 'Remaining Currency', 
		CASE WHEN Remaining_VND <> 0 THEN CONVERT(VARCHAR, CONVERT(BIGINT, Remaining_VND)) ELSE '' END AS 'Remaining VND'
FROM #Report

DROP TABLE #Transactions0
DROP TABLE #Transactions1
DROP TABLE #SummaryTransactions
DROP TABLE #EndingBalance
DROP TABLE #Report