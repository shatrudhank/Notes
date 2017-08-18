USE [Test]
GO

/****** Object:  StoredProcedure [dbo].[sys_push_lead_details_to_phone_banking_dialer_system]    Script Date: 18-08-2017 15:29:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/*--------------------------------------------------------------------------------------------------------------------------------------- 

Created By	: Umesh Thumar

Created On	: 28.05.2016

Description : Procedure used to push the new generated lead detail to ICICI Bank (Phone Banking Dialer Database)

ID			CHANGED ON				 CHANGED BY					         REASON
#001		18-08-2017				SHATRUDHAN KUMAR					TO IMPROVE PERFORMANCE 

-----------------------------------------------------------------------------------------------------------------------------------------

Source Table : tbl_mst_LeadDetails 

	SELECT * FROM tbl_mst_LeadDetails

Destination Table : Hyd_Topup_Loan_New

	SELECT * FROM Hyd_Topup_Loan_New

	SELECT * FROM openquery(GSCFGDB1, 'select * from Hyd_Topup_Loan_New')

Log Management : dbo.sys_event_audit_log

	SELECT * FROM dbo.sys_event_audit_log

----------------------------------------------------------------------------------------------------------------------------------------*/ 

ALTER PROCEDURE [dbo].[sys_push_lead_details_to_phone_banking_dialer_system]

AS 

BEGIN

	-- Added XACT_ABORT to ON because of 'Unable to start a nested transaction for OLE DB provider "OraOLEDB.Oracle" for linked server "GSCFGDB1". A nested transaction was required because the XACT_ABORT option was set to OFF.' error

	SET XACT_ABORT ON

	DECLARE		@error_no				INT = 0 

			,	@error_message			VARCHAR(max) = ''

			,	@current_record_id		DECIMAL(38,0) = NULL

			,	@current_chain_id		DECIMAL(38,0) = NULL

			,	@total_leads_to_push	INT = 0

			,	@lead_ids				VARCHAR(MAX) = ''

			,   @max_record_id          DECIMAL(38,0) = NULL					   --#001  

			,   @mar_chain_id           DECIMAL(38,0) = NULL					   --#001   


    SET TRAN ISOLATION LEVEL SERIALIZABLE										   --#001   To lock the resources 
	
	
	BEGIN distributed TRAN

	BEGIN TRY
	print('transaction started')
	
		--- Get all new generated lead details since the last job runs...

		SELECT ROW_NUMBER() OVER(ORDER BY intPKey) lead_record_id		--#001 removed order by desc since we want to maintain the order of leads recorder in Hyd_Topup_Loan_New

		, varCustomerName

		, varCustomerNumber

		, varProductIntrestedIn

		, varMobileNo 

		, varVehicleRegistrationNumber

		, left(varRemarks,100) varRemarks 

		, uniqueLeadId

		, dtCreatedOn

		, [Status]

		, varCreatedBy

		, varCreatedByEmailId

		, varCreatedByMobNo

		, varCreatedByDepartment

		INTO   #push_lead_records 

		FROM tbl_mst_LeadDetails WHERE is_lead_push = 0


		
		--- Get a int value that represents the number of lead to be push into ICICI Bank (Phone Banking Dialer Database)

		SELECT @total_leads_to_push = COUNT(*) FROM #push_lead_records

	
		
		IF(@total_leads_to_push > 0)

		BEGIN

				 set  @max_record_id= dbo.fn_GetMaxRecordID()					--#001 seting variable  maximum record id of  Hyd_Topup_Loan_New
		    	 set  @mar_chain_id =dbo.fn_GetMaxChainID()						--#001 seting variable  maximum chain id of  Hyd_Topup_Loan_New   
		
		   print(@max_record_id)
		   waitfor delay '00:01'
			    SELECT @lead_ids= CAST(uniqueLeadId as varchar(20)) + coalesce(',' + @lead_ids , '') FROM	#push_lead_records
			
		
				--- Push a new generated lead to ICICI Bank (Phone Banking Dialer Database)
		print('insert into open query')
		INSERT OPENQUERY 

				(	oracle_12c,

					'SELECT

						RECORD_ID

					,	CHAIN_ID

					,	CONTACT_INFO_TYPE

					,	RECORD_TYPE

					,	RECORD_STATUS

					,	CALL_RESULT

					,	ATTEMPT

					,	DAILY_FROM

					,	DAILY_TILL

					,	TZ_DBID

					,	CHAIN_N

					,	Lead_Id

					,	Customer_Name

					,	SB_ACCNO

					,	Account_No

					,	GI_Product_Int_In

					,	Product

					,	CONTACT_INFO

					,	Mobile_No

					,	VehicleRegNo

					,	Remarks 

					,	Initiated_On

					,	Status

					,	Dummy_1

					,	Dummy_2

					,	Dummy_3

					,	Dummy_4

					FROM Hyd_Topup_Loan'

				)

				SELECT 

					--  <Calculated Fields>

					    @max_record_id + lead_record_id				--#001
				 
				    ,   @mar_chain_id + lead_record_id				--#001

			

					-- <Set the default values>

					,	4

					,	2

					,	1

					,	28

					,	0

					,	28800

					,	64800

					,	109

					,	0

					-- <Lead data through iPolicy App>

					,	uniqueLeadId

					,	left(varCustomerName,100) 

					,	varCustomerNumber

					,	left(varCustomerNumber,20) 

					,	varProductIntrestedIn

					,	left(varProductIntrestedIn,80)

					,	'5410'+varMobileNo

					,	varMobileNo 

					,	varVehicleRegistrationNumber

					,	left(varRemarks,100)

					,	dtCreatedOn

					,	case when [Status] IS NULL or [Status] = ''

								then '1'

								else left([Status],20)

						   end as [Status]

					,	varCreatedBy

					,	case when varCreatedByEmailId IS NULL or varCreatedByEmailId = ''

								then '1'

								else left(varCreatedByEmailId,50)

						   end as varCreatedByEmailId

					,	case when varProductIntrestedIn IS NULL or varProductIntrestedIn = ''

								then '1'

								else left(varProductIntrestedIn,50)

						   end as varProductIntrestedIn

					,	case when varRemarks IS NULL or varRemarks = ''

								then '1'

								else left(varRemarks,50)

						   end as varRemarks

				FROM	#push_lead_records

			print('insert succeed')
	

			UPDATE	lead

			SET		lead.is_lead_push = 1

			FROM	dbo.tbl_mst_LeadDetails lead

					JOIN #push_lead_records temp

						ON lead.uniqueLeadId = temp.uniqueLeadId 	

			print('updated table')

			-- event log if the lead is pushed successfully..

			--INSERT INTO [dbo].[sys_event_audit_log]

			--VALUES

			--	   ('PUSH'

			--	   ,GETDATE()

			--	   ,'Finished'

			--	   ,'Lead ('+ @lead_ids +') has been pushed successfully.'

			--	   ,NULL

			--	   ,NULL)

		END

		-- Log the information if no leads found to push.

		ELSE

		BEGIN
			PRINT('NO LEAD')

			INSERT INTO [dbo].[sys_event_audit_log]

			VALUES

				   ('PUSH'

				   ,GETDATE()

				   ,'Finished'

				   ,'No new leads found.'

				   ,NULL

			   ,NULL)

		END
			COMMIT TRAN;
			   

	END TRY



	BEGIN CATCH
	     print(error_message())
		ROLLBACK TRAN;
		print('insert error')
		INSERT INTO [dbo].[sys_event_audit_log]

		VALUES

			   ('PUSH'

			   ,GETDATE()

			   ,'Failed'

			   ,'System failed to push the leads '+ @lead_ids

			   ,ERROR_NUMBER()

			   ,ERROR_MESSAGE())

	END CATCH 

	
END 



SET XACT_ABORT OFF

SET NOCOUNT OFF







GO


