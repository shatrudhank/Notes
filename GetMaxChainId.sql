USE [Test]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetMaxChainID]    Script Date: 18-08-2017 15:30:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[fn_GetMaxChainID]() 
RETURNS INT
AS
BEGIN
	DECLARE @max_chain_id DECIMAL(38,0)=0
	SELECT	@max_chain_id = 
			CASE 
				WHEN MAX(CHAIN_ID) IS NULL THEN 0
				ELSE MAX(CHAIN_ID)
			END
	FROM openquery(oracle_12c,'select chain_id from hyd_topup_loan')
	RETURN @max_chain_id
END


