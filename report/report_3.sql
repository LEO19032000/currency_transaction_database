USE [BANK_TEST]
GO
/****** Object:  StoredProcedure [dbo].[usp_VND_Earned_At_Banks]    Script Date: 9/19/2024 2:49:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_VND_Earned_At_Banks]
AS

-- Requirement 4: Use SQL query to summarize VND earned from foreign currency sales at banks

DECLARE @_BankCode NVARCHAR(MAX) = N'Bank Code', @_BankName NVARCHAR(MAX) = N'Bank Name',
		@_Sale NVARCHAR(MAX) = N'', @_Sale1 NVARCHAR(MAX) = N'',
		@_Sum2 NVARCHAR(MAX) = N'', @_StrExec2 NVARCHAR(MAX) = N'',
		@_TotalVND NVARCHAR(64) = N'Total VND', @_TotalAllVND NVARCHAR(64) = N'Total'

IF OBJECT_ID('tempdb..#BankSales') IS NOT NULL DROP TABLE #BankSales
SELECT Tb2.BankCode, ISNULL(MAX(Tb3.BankName), 0) AS BankName, Tb1.CurrencyCode, SUM(Tb1.VND) AS VND
	INTO #BankSales
	FROM CurDocDetail Tb1
		INNER JOIN CurDoc Tb2 ON Tb1.DocNo = Tb2.DocNo
		LEFT OUTER JOIN Bank Tb3 ON Tb2.BankCode = Tb3.BankCode
	WHERE Tb2.DocGroup = 2
	GROUP BY Tb1.CurrencyCode, Tb2.BankCode

SELECT @_Sale += 'ISNULL(' + CurrencyCode + ', 0) AS [Sale ' + CurrencyCode + '], '
	FROM #BankSales 
	GROUP BY CurrencyCode
	ORDER BY CurrencyCode
SET @_Sale = LEFT(@_Sale, LEN(@_Sale) - 1)
print @_Sale

SELECT @_Sale1 += '[' + CurrencyCode + '], ' FROM #BankSales GROUP BY CurrencyCode ORDER BY CurrencyCode
SET @_Sale1 = LEFT(@_Sale1, LEN(@_Sale1) - 1)

SET @_Sum2 = REPLACE('ISNULL(' + REPLACE(@_Sale1, ', ', ', 0), ISNULL(') + ', 0)', '),', ') +')
print @_Sum2

SELECT @_StrExec2 =
		'SELECT		CONVERT(VARCHAR, ROW_NUMBER() OVER (ORDER BY BankCode)) AS No, 
			BankCode AS ' + CHAR(39) + @_BankCode + CHAR(39) + ', 
			BankName AS ' + CHAR(39) + @_BankName + CHAR(39) + ',
			' + @_Sale + ', 
			' + @_Sum2 + ' AS ' + CHAR(39) + @_TotalVND + CHAR(39) + '
		FROM #BankSales
		PIVOT (SUM (VND) FOR CurrencyCode IN (' + @_Sale1 + ')) AS Tb1
		UNION ALL
		SELECT 	'''',
			'''',
			 ' + CHAR(39) + @_TotalAllVND + CHAR(39) + ', 
			' + @_Sale1 + ', 
			' + @_Sum2 + '
		FROM (SELECT CurrencyCode, VND FROM #BankSales) AS Tb2		
		PIVOT  (SUM (VND) FOR CurrencyCode IN (' + @_Sale1 + ')) AS Tb3'

EXEC (@_StrExec2)
print(@_StrExec2)
DROP TABLE #BankSales
