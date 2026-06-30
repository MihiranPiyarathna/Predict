DECLARE @RC int
DECLARE @CKy int = '1237'
DECLARE @Dt date = CURRENT_DATE
DECLARE @AccKy bigint = '594557' -- '629625' -- '620876' -- no data in db 
DECLARE @AccTypKy int = '1'
DECLARE @BUKy int = '1' --'620231'
DECLARE @AdrKy bigint  = '1'-- = '1357951'
DECLARE @RepAdrKy bigint = '1'
DECLARE @PrjKy bigint = '1'
DECLARE @OrdKy bigint = '1'
DECLARE @AdrCat1Ky int = '1'
DECLARE @AdrCat2Ky int = '1'
DECLARE @AdrCat3Ky int = '1'
DECLARE @AccCat1Ky int = '1'
DECLARE @AccCat2Ky int = '1'
DECLARE @AccCat3Ky int = '1'
DECLARE @NoOfDys1 int = '30'
DECLARE @NoOfDys2 int = '60'
DECLARE @NoOfDys3 int = '90'
DECLARE @NoOfDys4 int = '120'
DECLARE @NoOfDys5 int = '150'
DECLARE @ObjKy int = '1'
DECLARE @isOverDue bit -- = 1
DECLARE @UsrKy bigint = '28' --'344972'
DECLARE @isHideMinusAmt bit = 0

-- TODO: Set parameter values here.

EXECUTE @RC = [dbo].[PFAccAgeAnlDr_ReportWeb] 
   @CKy
  ,@Dt
  ,@AccKy
  ,@AccTypKy
  ,@BUKy
  ,@AdrKy
  ,@RepAdrKy
  ,@PrjKy
  ,@OrdKy
  ,@AdrCat1Ky
  ,@AdrCat2Ky
  ,@AdrCat3Ky
  ,@AccCat1Ky
  ,@AccCat2Ky
  ,@AccCat3Ky
  ,@NoOfDys1
  ,@NoOfDys2
  ,@NoOfDys3
  ,@NoOfDys4
  ,@NoOfDys5
  ,@ObjKy
  ,@isOverDue
  ,@UsrKy
  ,@isHideMinusAmt
GO