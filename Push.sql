USE [Test]
GO
/****** Object:  StoredProcedure [dbo].[sys_pull_lead_details_from_phone_banking_dialer_system]    Script Date: 18-08-2017 15:27:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*-----------------------------------------------------------------------------------------------------------------------------------------------
Created By : Umesh Thumar
Created On : 02.06.2016
Description : Used for reverse integration for closure status of the lead to be fetched from Dialler to I-Policy App through the Data base link.
-------------------------------------------------------------------------------------------------------------------------------------------------
Source Table		: Hyd_Topup_Loan	  | SELECT * FROM Hyd_Topup_Loan  | select * from openquery(genuat1, 'select * from HYd_Topup_LOan')
Destination Table	: tbl_mst_LeadDetails | SELECT * FROM tbl_mst_LeadDetails
Event Audit Log		: sys_event_audit_log |	SELECT * FROM dbo.sys_event_audit_log
Lead Status Master  : LEAD_STATUS		  | SELECT * FROM LEAD_STATUS		
------------------------------------------------------------------------------------------------------------------------------------------------
Possible Lead Status ( Table: LEAD_STATUS )

id 		description			Status
0 		No record status	N/A
1 		Ready				Open
2 		Retrieved			In Progress
3 		updated				Closed
4 		stale				Closed
5 		Cancelled			Closed
6 		Agent error			Closed
7 		chain updated		Closed
8 		Missed call back	Closed
9 		chain ready			Closed

NOTE: 
1. Whenever the lead status is updated to Closed in Hyd_Topup_Loan then we need to set 'DISPOSITION' value as a 'Status' instead of 'Closed'
2. Whenever the lead status is updated to Closed in Hyd_Topup_Loan then we need to set 'CALL_TIME' value as a 'dateofCallclosure' and mark 'IsCallClosed' flag to 1.
3. System will not update any details once the lead closed.
4. The following lead details will not changed through ICICI Phone banking dialer, so no need to update it during reverse integration.
	- Customer Name
	- Customer Account Number
	- Product
	- Customer Mobile Number
	- Vehicle Registration Number
	- Remark
------------------------------------------------------------------------------------------------------------------------------------------------
Following are the CALL_RESULT code maintain through ICICI Phone Banking Dialer. This is stored in 'CALL_RESULT' field of 'Hyd_Topup_Loan'.

CALL_RESULT field description 

ANSWER			33
ANSMACH			9
BUSY			6
NOANSWR			7
WRONG			28
MODEM			7
FAX				17
SIT_TONE		14
GENERAL_ERROR	3
DIAL_ERROR		41
SYSTEM_ERROR	4
DIAL_DROPPED	26
DIAL_TONE		35
SILENCE			32
DROPPED			26
NORPC			40
NU_TONE			34
ABANDONED		21
PAGER			39
UNKNOWN			28
------------------------------------------------------------------------------------------------------------------------------------------------*/ 
ALTER PROCEDURE [dbo].[sys_pull_lead_details_from_phone_banking_dialer_system]
AS 
BEGIN

	DECLARE		@error_no				INT = 0 
			,	@error_message			VARCHAR(max) = ''
			,	@total_pulled_leads		INT = 0

	BEGIN TRAN
	BEGIN TRY
			
			SELECT * INTO #Hyd_Topup_Loan from openquery(oracle_12c, 'select * from HYd_Topup_Loan')

			UPDATE	lead
			SET		lead.Policyno = htl.PolicyNo
				,	lead.Premium = htl.Premium
				--  Whenever the lead status is updated to Closed in Hyd_Topup_Loan then we need to set 'CALL_TIME' value as a 'dateofCallclosure'.
				,	lead.dateofCallclosure = CASE
												WHEN htl.RECORD_STATUS IN (3,4,5,6,7,8,9) THEN GETDATE() --htl.CALL_TIME  --Todo: Need to convert Numeric to DateTime
												ELSE NULL
											END 
				--  Whenever the lead status is updated to Closed in Hyd_Topup_Loan then mark 'IsCallClosed' flag to 1.
				,	lead.IsCallClosed = CASE
											WHEN htl.RECORD_STATUS IN (3,4,5,6,7,8,9) THEN 1
											ELSE 0
										END 
				,	lead.lead_status_id = htl.RECORD_STATUS 
				--  Whenever the lead status is updated to Closed in Hyd_Topup_Loan then we need to set 'DISPOSITION' value as a 'Status' instead of 'Closed'
				,	lead.Status = CASE
									WHEN htl.RECORD_STATUS = 1 THEN 'Open'
									WHEN htl.RECORD_STATUS = 2 THEN 'In Progress'
									ELSE htl.DISPOSITION
								  END
				,	lead.dtModifiedOn = GETDATE()
			FROM	dbo.tbl_mst_LeadDetails lead
					JOIN LEAD_STATUS ls
						ON lead.lead_status_id = ls.id
						AND ls.status in ('Open','In Progress')
					JOIN #Hyd_Topup_Loan htl
						ON lead.uniqueLeadId = htl.Lead_Id
						AND	lead.lead_status_id != htl.RECORD_STATUS
			
			-- event log if the lead is pushed successfully..
			INSERT INTO [dbo].[sys_event_audit_log]
			VALUES
				   ('PULL'
				   ,GETDATE()
				   ,'Finished'
				   ,'Lead details has been pulled successfully.'
				   ,NULL
				   ,NULL)
				   
			COMMIT TRAN;				   
		
	END TRY

	BEGIN CATCH
		ROLLBACK TRAN;
		--SELECT @error_no = ERROR_NUMBER(), @error_message = ERROR_MESSAGE()
		INSERT INTO [dbo].[sys_event_audit_log]
		VALUES
			   ('PULL'
			   ,GETDATE()
			   ,'Failed'
			   ,'System failed to update the lead details.'
			   ,ERROR_NUMBER()
			   ,ERROR_MESSAGE())
	END CATCH 

	DROP TABLE #Hyd_Topup_Loan
END

SET NOCOUNT OFF


