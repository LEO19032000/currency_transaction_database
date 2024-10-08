USE [BANK_TEST]
GO
/****** Object:  StoredProcedure [dbo].[usp_Currency_Purchases_At_Banks]    Script Date: 9/19/2024 2:48:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_Currency_Purchases_At_Banks]
AS 
-- Requirement 3: Use SQL query to summarize foreign currency purchases at banks

DECLARE @_CurrencyCode NVARCHAR(MAX) = N'Currency Code', @_CurrencyName NVARCHAR(MAX) = N'Currency Name',
		@_Bank NVARCHAR(MAX) = N'', @_Bank1 NVARCHAR(MAX) = N'',
		@_Sum NVARCHAR(MAX) = N'', @_StrExec NVARCHAR(MAX) = N'',
		@_TotalPurchase NVARCHAR(64) = N'Total Purchase' , @_TotalAll NVARCHAR(64) = N'Total'

IF OBJECT_ID('tempdb..#BankPurchases') IS NOT NULL DROP TABLE #BankPurchases
SELECT Tb1.CurrencyCode, ISNULL(MAX(Tb3.CurrencyName), 0) AS CurrencyName, Tb2.BankCode, SUM(Tb1.VND) AS VND
	INTO #BankPurchases
	FROM CurDocDetail Tb1
		LEFT OUTER JOIN CurDoc Tb2 ON Tb1.DocNo = Tb2.DocNo
		LEFT OUTER JOIN Currency Tb3 ON Tb1.CurrencyCode = Tb3.CurrencyCode
	WHERE Tb2.DocGroup = 1
	GROUP BY Tb1.CurrencyCode, Tb2.BankCode

SELECT @_Bank += 'ISNULL(' + T1.BankCode + ', 0) AS [' + Tb2.BankName + '], '
	FROM #BankPurchases T1 LEFT OUTER JOIN Bank Tb2 ON T1.BankCode = Tb2.BankCode
	GROUP BY T1.BankCode, Tb2.BankName
	ORDER BY T1.BankCode
SET @_Bank = LEFT(@_Bank, LEN(@_Bank) - 1)

SELECT @_Bank1 += '[' + BankCode + '], ' FROM #BankPurchases GROUP BY BankCode ORDER BY BankCode
SET @_Bank1 = LEFT(@_Bank1, LEN(@_Bank1) - 1)

SET @_Sum = REPLACE('ISNULL(' + REPLACE(@_Bank1, ', ', ', 0), ISNULL(') + ', 0)', '),', ') +')

SELECT @_StrExec =
		'SELECT		CONVERT(VARCHAR, ROW_NUMBER() OVER (ORDER BY CurrencyCode)) AS No, 
			CurrencyCode AS ' + CHAR(39) + @_CurrencyCode + CHAR(39) +', 
			CurrencyName AS ' + CHAR(39) + @_CurrencyName + CHAR(39) + ',
			' + @_Bank + ', 
			' + @_Sum + ' AS ' + CHAR(39) + @_TotalPurchase + CHAR(39) + '
		FROM #BankPurchases
		PIVOT (SUM (VND) FOR BankCode IN (' + @_Bank1 + ')) AS Tb1
		UNION ALL
		SELECT 	'''',
			'''',
			 ' + CHAR(39) + @_TotalAll + CHAR(39) + ', 
			' + @_Bank1 + ', 
			' + @_Sum + ' 
		FROM (SELECT BankCode, VND FROM #BankPurchases) AS Tb2		
		PIVOT  (SUM (VND) FOR BankCode IN (' + @_Bank1 + ')) AS Tb3'

EXEC (@_StrExec)
DROP TABLE #BankPurchases