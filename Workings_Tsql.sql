DECLARE @RC int
declare
	@AdrKy bigint =1, --1317054,	--1317046
	@LocKy int =1317054,
	@Dt date=CURRENT_DATE ,
	@DefNoOfMonths smallint = 12,
	@CKy int=1237,
	@ObjKy int=12586,
	@UsrKy int =28;


-- TODO: Set parameter values here.

EXECUTE [dbo].[PAdrKyPOPrediction_SelectWeb] 
   @AdrKy
  ,@LocKy
  ,@Dt
  ,@DefNoOfMonths
  ,@CKy
  ,@ObjKy
  ,@UsrKy
GO

-- exec sp_helptext '[dbo].[PAdrKyPOPrediction_SelectWeb]';
-- select object_definition(OBJECT_ID('[dbo].[PAdrKyPOPrediction_SelectWeb]'));