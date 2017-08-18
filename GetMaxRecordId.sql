USE [Test]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetMaxRecordID]    Script Date: 18-08-2017 15:31:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER FUNCTION [dbo].[fn_GetMaxRecordID]() 
RETURNS INT
AS
BEGIN
	DECLARE @max_record_id DECIMAL(38,0)=0
	SELECT	@max_record_id = 
			CASE 
				WHEN MAX(RECORD_ID) IS NULL THEN 0
				ELSE MAX(RECORD_ID) 
			END
	FROM openquery(oracle_12c,'select record_id from hyd_topup_loan')
	RETURN @max_record_id
END
