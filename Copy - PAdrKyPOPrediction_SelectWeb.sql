-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
------ =============================================

-- declare
-- 	@AdrKy bigint=1317050,	--1317046
-- 	@LocKy int =640060,
-- 	@Dt date='2025/11/12' ,
-- 	@DefNoOfMonths smallint = 12,
-- 	@CKy int=1237,
-- 	@ObjKy int=1,
-- 	@UsrKy int =28

CREATE PROCEDURE [dbo].[PAdrKyPOPrediction_SelectWeb]
	@AdrKy bigint,
	@LocKy int =1,
	@Dt date , 
  @DefNoOfMonths smallint = 1,
	@CKy int,
	@ObjKy int,
	@UsrKy int 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @POTypKy int,  @SalesBgtTypKy int , @SlsOrdTypKy int
	
	select @SalesBgtTypKy = CdKy from CdMas where CKy = @CKy  and ConCd = 'ItmBgtTyp' and OurCd = 'PredSls'
	select @POTypKy = CdKy from CdMas where CKy = @CKy and ConCd   = 'OrdTyp' and OurCd = 'PO'
	select @SlsOrdTypKy = CdKy from CdMas where CKy = @CKy and ConCd   = 'OrdTyp' and OurCd = 'SlsOrd'

	   declare @DtSt date , @DtEnd date 
SELECT @DtSt = DATEADD(MONTH, DATEDIFF(MONTH, 0, @Dt), 0) 
select @DtEnd =  DATEADD (MONTH , (@DefNoOfMonths * -1) , @DtSt)

print @DtSt
print @DtEnd


	   create table #Results
	   (
	   ItmKy bigint,
	   ItmCd varchar(100),
	   ItmNm nvarchar(250),
	   UnitKy bigint,
	   Unit varchar(100),
	   Rate decimal(18, 2),
	   LstPODt date default '1900/1/1', 
	   PredSlsQty decimal(18, 3) default 0 ,
	   AvgSale  decimal(18, 3) default 0 ,
	   SalesForPO	 decimal(18, 3)default 0 ,
	   StkInHand  decimal(18, 3) default 0 ,
	   PendPOQty  decimal(18, 3) default 0 ,
	   PendSlsOrdQty  decimal(18, 3) default 0 ,
	   BufferStk decimal(18, 3) default 0 ,
	   LeadTime smallint default 0 ,
	   MinOrdQty decimal(18, 3) default 0 ,
	   CalcPOQty decimal(18, 3) default 0 ,
	   ProcurPlnQty decimal(18, 3) default 0 	,
	   LeadTime1 int,
	   LeadTime2 int,
	   LeadTime3 int
	   )

	   create table #POGRNDet
	   (
	   ItmKy bigint, 
	   GRNDt date ,
	   GRNKy bigint,
	   Itr tinyint,
	   PODt date,
	   POKy bigint,
	   LeadTime smallint 
	   )

	   insert into #Results (ItmKy, ItmCd, ItmNm, UnitKy)
	   select ItmKy , ItmCd, ItmNm,UnitKy
	   from ItmMas where CKy = @CKy and  (DefaultSupAdrKy = @AdrKy or @AdrKy = 1)
	   and isAct =1  and isAlwTrn=1

	   

	   UPDATE #Results
	   set Unit =UnitMas.Unit
	   From #Results  INNER JOIN UnitMas ON  UnitMas.UnitKy = #Results.UnitKy

	   BEGIN
	   declare @PriCtrlLocKy int = 1, @ControlConKy int 

	   select Top(1) @PriCtrlLocKy = CdMas.Cdky 
	   from CdMasPrnt INNER JOIN CdMas on CdMas.CdKy = CdMasPrnt.PrntCdKy 
	   where CdMasPrnt.CdKy = @LocKy AND isCd09= 1 and ConCd = 'Loc'

	   if @PriCtrlLocKy = 1
	      select Top(1) @PriCtrlLocKy = CdMas.Cdky 
	   from CdMas 
	   where CKy = @CKy AND isCd09= 1 and ConCd = 'Loc'

	   select @ControlConKy = ControlConKy from ControlCon where TblNm ='ItmRate' and OurCd = 'ItmRateItmCos'

	   UPDATE #Results
	   set Rate = Main.Rate from 
	   #Results inner join 
	   (
	   select Stp.ItmKy, ItmRate.Rate
	   from (
	   select #Results.ItmKy , MAX(EftvDt) as EftvDt
	   from #Results INNER JOIN 
	   ItmRate on ItmRate.ItmKy =  #Results.ItmKy 
	   where ControlConKy = @ControlConKy and EftvDt <= @Dt and ItmRate.isAct = 1 and LocKy = @PriCtrlLocKy
	   group by #Results.ItmKy) as Stp INNER JOIN ItmRate on ItmRate.ItmKy = Stp.ItmKy and ItmRate.EftvDt = Stp.EftvDt
	   where ItmRate.ControlConKy = @ControlConKy and isAct =1 and LocKy = @PriCtrlLocKy
	   ) as Main on Main.ItmKy = #Results.ItmKy
	 End



	UPDATE #Results
	set LstPODt = Stp.LstPODt
	from #Results INNER JOIN (
		SELECT top(1) MAX(OrdDt) as LstPODt , OrdDet.ItmKy
FROM   OrdDet INNER JOIN
             OrdHdr ON OrdDet.Ordky = OrdHdr.OrdKy INNER JOIN 
			 #Results ON #Results.ItmKy = OrdDet.ItmKy
WHERE (OrdHdr.CKy = @CKy) AND (OrdHdr.OrdDt <= @Dt) AND (OrdHdr.OrdTypKy = @POTypKy) 
AND (OrdDet.isAct = 1) AND (OrdDet.isApr = 1) AND (OrdHdr.IsAct = 1) AND (OrdHdr.IsApr = 1)
group by OrdDet.ItmKy ) as Stp ON Stp.ItmKy = #Results.ItmKy;




;WITH RankedGRN AS (
    SELECT 
        ItmTrn.ItmKy, 
        EftvDt, 
       TrnKy , 
        ROW_NUMBER() OVER (PARTITION BY ItmTrn.ItmKy ORDER BY EftvDt DESC) AS rn
    FROM ItmTrn inner join #Results on #Results.ItmKy = ItmTrn.ItmKy inner join 
	CdMas on CdMas.CdKy = ItmTrn.TrnTypKy
	where ItmTrn.CKy = @CKy and CdMas.CKy = @CKy and isCd90 = 1 and CdNo1 >0 and ItmTrn.EftvDt <= @Dt and ItmTrn.isAct = 1 and (ItmTrn.AdrKy = @AdrKy or @AdrKy = 1)
)

insert into #POGRNDet(ItmKy , GRNDt, GRNKy, Itr)
SELECT ItmKy, EftvDt, TrnKy, rn
FROM RankedGRN
WHERE rn <= 3
ORDER BY ItmKy, EftvDt DESC;

UPDATE #POGRNDet
set POKy = OrdHdrTrnHdr.OrdKy , PODt = OrdHdr.OrdDt
from #POGRNDet inner join OrdHdrTrnHdr on #POGRNDet.GRNKy = OrdHdrTrnHdr.TrnKy
inner join OrdHdr on OrdHdr.OrdKy = OrdHdrTrnHdr.OrdKy
where OrdHdr.OrdTypKy = @POTypKy

UPDATE #POGRNDet 
set LeadTime = DATEDIFF (Day, PODt, GrnDt)

UPDATE #Results
set LeadTime1 = #POGRNDet.LeadTime
from #Results inner join #POGRNDet on #POGRNDet.ItmKy = #Results.ItmKy 
where #POGRNDet.Itr = 1

UPDATE #Results
set LeadTime2 = #POGRNDet.LeadTime
from #Results inner join #POGRNDet on #POGRNDet.ItmKy = #Results.ItmKy 
where #POGRNDet.Itr = 2

UPDATE #Results
set LeadTime3= #POGRNDet.LeadTime
from #Results inner join #POGRNDet on #POGRNDet.ItmKy = #Results.ItmKy 
where #POGRNDet.Itr = 3



--UPDATE #Results
--set PredSlsQty = Stp.Qty
--from #Results inner join (
--select  sum(Qty) as Qty , #Results.ItmKy
--from ItmBgt INNER JOIN #Results on #Results.ItmKy = ItmBgt.ItmKy
--where ItmBgtTypKy = @SalesBgtTypKy and BgtDt >= LstPODt and BgtDt <= @Dt and CKy = @CKy
--group by #Results.ItmKy
--) as Stp ON Stp.ItmKy = #Results.ItmKy


UPDATE #Results
set PredSlsQty = Stp.Qty
from #Results inner join (
select Stp1.ItmKy , ItmBgt.Qty from (
select   #Results.ItmKy, min(BgtDt) as BgtDt
from ItmBgt INNER JOIN #Results on #Results.ItmKy = ItmBgt.ItmKy
where ItmBgtTypKy = @SalesBgtTypKy and BgtDt >= @Dt and CKy = @CKy
group by #Results.ItmKy
) as Stp1 inner join ItmBgt on Stp1.ItmKy = ItmBgt.ItmKy and Stp1.BgtDt = ItmBgt.BgtDt 
where  ItmBgtTypKy = @SalesBgtTypKy and ItmBgt.BgtDt >= @Dt and CKy = @CKy
) as Stp ON Stp.ItmKy = #Results.ItmKy



UPDATE #Results
set AvgSale = ABS(Main.AvgSale)
from #Results INNER JOIN (
select ItmKy , SUM(SaleQty) / @DefNoOfMonths  as AvgSale
from 
(SELECT DimDate.Month, (ItmQtyDtX.Qty) SaleQty , ItmQtyDtX.ItmKy
FROM   ItmQtyDtX INNER JOIN #Results ON #Results.ItmKy = ItmQtyDtX.ItmKy INNER JOIN 
             CdMas ON ItmQtyDtX.TrnTypKy = CdMas.CdKy INNER JOIN
             DimDate ON ItmQtyDtX.EftvDt = DimDate.Date
WHERE (ItmQtyDtX.CKy = @CKy) AND (CdMas.isCd91 = 1) AND (ItmQtyDtX.EftvDt >= @DTEnd) AND (ItmQtyDtX.EftvDt <= @DtSt)
AND (ItmQtyDtX.isInventory =1)
) as Stp 
group by ItmKy ) as Main ON Main.ItmKy = #Results.ItmKy

UPDATE #Results
set SalesForPO = CASE WHEN PredSlsQty > AvgSale THEN PredSlsQty else AvgSale END 

UPDATE #Results
set StkInHand = Stp.Qty 
from #Results INNER JOIN (
select #Results.ItmKy , SUM(qty) as Qty
from #Results inner join ItmQtyDtX on ItmQtyDtX.ItmKy = #Results.ItmKy
inner join cdmas as Loc on Loc.CdKy = ItmQtyDtX.LocKy
where EftvDt <= @Dt and ItmQtyDtX.CKy = @CKy and isInventory=1  and Loc.IsCd05 = 0 and Loc.isCd25 = 0
group by #Results.ItmKy ) as Stp ON Stp.ItmKy = #Results.ItmKy

UPDATE #Results 
set PendPOQty =BalPOQty
from #Results inner join (
select ItmKy, SUM(BalPOQty ) as BalPOQty from ( 

SELECT  OH.Qty - ISNULL(Sale.SaleQty, 0) - ISNULL(SOCancl.SOCanclQty, 0) AS BalPOQty , OH.ItmKy
               
FROM    
                  (SELECT #results.ItmKy, OrdDetKy, Qty , OrdDt, ReqDt
				  from OrdHdr with (NOLOCK)
INNER JOIN OrdDet WITH (nolock) ON OrdHdr.OrdKy = OrdDet.Ordky INNER JOIN #Results ON #Results.ItmKy = OrdDet.ItmKy
WHERE
(OrdHdr.CKy = @CKy) AND (OrdHdr.CKy = @CKy) AND (OrdTypKy = @POTypKy) AND (OrdDet.isAct = 1) AND 
(OrdDet.isApr = 1) AND (OrdDet.IsSetOff = 0) AND (OrdHdr.IsAct = 1) and  (OrdHdr.OrdDt <= @Dt)  
) as OH                             
                 LEFT OUTER JOIN
                      (SELECT CdMas_1.CKy, OrdDet_1.ItmKy, OrdDet_1.Qty AS SOCanclQty, OrdDetSetOff.CrOrdDetKy AS OrdDetKy
                       FROM      CdMas AS CdMas_1 WITH (nolock) INNER JOIN
                                         OrdHdr AS OrdHdr_1 WITH (nolock) ON CdMas_1.CdKy = OrdHdr_1.OrdTypKy INNER JOIN
                                         OrdDet AS OrdDet_1 WITH (nolock) ON OrdHdr_1.OrdKy = OrdDet_1.Ordky INNER JOIN
                                         OrdDetSetOff WITH (nolock) ON OrdDet_1.OrdDetKy = OrdDetSetOff.DrOrdDetKy INNER JOIN #Results ON #Results.ItmKy = OrdDet_1.ItmKy
                       WHERE   (CdMas_1.CKy = @CKy) AND (CdMas_1.ConCd = 'OrdTyp') AND (CdMas_1.OurCd = 'SlsOrdCancl') AND (OrdDet_1.isAct = 1) AND (OrdDet_1.isApr = 1) ) AS SOCancl ON OH.OrdDetKy = SOCancl.OrdDetKy LEFT OUTER JOIN
                      (SELECT OrdItmSetOff_1.OrdDetKy, SUM(ItmTrn_1.Qty) AS SaleQty
                       FROM      ItmTrn AS ItmTrn_1 WITH (nolock) INNER JOIN
                                         OrdItmSetOff AS OrdItmSetOff_1 WITH (nolock) ON ItmTrn_1.ItmTrnKy = OrdItmSetOff_1.ItmTrnKy
										 INNER JOIN #Results ON #Results.ItmKy = ItmTrn_1.ItmKy
                       WHERE   (ItmTrn_1.isAct = 1) AND (ItmTrn_1.isApr = 1) 
                       GROUP BY OrdItmSetOff_1.OrdDetKy) AS Sale ON OH.OrdDetKy = Sale.OrdDetKy
WHERE   
(OH.Qty > ISNULL(Sale.SaleQty, 0))  AND (OH.Qty - ISNULL(Sale.SaleQty, 0) - ISNULL(SOCancl.SOCanclQty, 0) >= 0.001)
) as Stp group by ItmKy
) as Main on Main.itmky = #Results.ItmKy


UPDATE #Results 
set PendSlsOrdQty =BalSlsOrdQty
from #Results inner join (
select ItmKy, SUM(BalSlsOrdQty ) as BalSlsOrdQty from ( 

SELECT  OH.Qty - ISNULL(GRN.GrnQty, 0) - ISNULL(POCancl.POCanclQty, 0) AS BalSlsOrdQty , OH.ItmKy
               
FROM    
                  (SELECT #results.ItmKy, OrdDetKy, Qty , OrdDt, ReqDt
				  from OrdHdr with (NOLOCK)
INNER JOIN OrdDet WITH (nolock) ON OrdHdr.OrdKy = OrdDet.Ordky INNER JOIN #Results ON #Results.ItmKy = OrdDet.ItmKy
WHERE
(OrdHdr.CKy = @CKy) AND (OrdHdr.CKy = @CKy) AND (OrdTypKy = @SlsOrdTypKy) AND (OrdDet.isAct = 1) AND 
(OrdDet.isApr = 1) AND (OrdDet.IsSetOff = 0) AND (OrdHdr.IsAct = 1) and  (OrdHdr.OrdDt <= @Dt)  
) as OH                             
                 LEFT OUTER JOIN
                      (SELECT CdMas_1.CKy, OrdDet_1.ItmKy, OrdDet_1.Qty AS POCanclQty, OrdDetSetOff.CrOrdDetKy AS OrdDetKy
                       FROM      CdMas AS CdMas_1 WITH (nolock) INNER JOIN
                                         OrdHdr AS OrdHdr_1 WITH (nolock) ON CdMas_1.CdKy = OrdHdr_1.OrdTypKy INNER JOIN
                                         OrdDet AS OrdDet_1 WITH (nolock) ON OrdHdr_1.OrdKy = OrdDet_1.Ordky INNER JOIN
                                         OrdDetSetOff WITH (nolock) ON OrdDet_1.OrdDetKy = OrdDetSetOff.DrOrdDetKy INNER JOIN #Results ON #Results.ItmKy = OrdDet_1.ItmKy
                       WHERE   (CdMas_1.CKy = @CKy) AND (CdMas_1.ConCd = 'OrdTyp') AND (CdMas_1.OurCd = 'POCancl') AND (OrdDet_1.isAct = 1) AND (OrdDet_1.isApr = 1) ) AS POCancl ON OH.OrdDetKy = POCancl.OrdDetKy LEFT OUTER JOIN
                      (SELECT OrdItmSetOff_1.OrdDetKy, SUM(ItmTrn_1.Qty) AS GrnQty
                       FROM      ItmTrn AS ItmTrn_1 WITH (nolock) INNER JOIN
                                         OrdItmSetOff AS OrdItmSetOff_1 WITH (nolock) ON ItmTrn_1.ItmTrnKy = OrdItmSetOff_1.ItmTrnKy
										 INNER JOIN #Results ON #Results.ItmKy = ItmTrn_1.ItmKy
                       WHERE   (ItmTrn_1.isAct = 1) AND (ItmTrn_1.isApr = 1) 
                       GROUP BY OrdItmSetOff_1.OrdDetKy) AS GRN ON OH.OrdDetKy = GRN.OrdDetKy
WHERE   
(OH.Qty > ISNULL(GRN.GrnQty, 0))  AND (OH.Qty - ISNULL(GRN.GrnQty, 0) - ISNULL(POCancl.POCanclQty, 0) >= 0.001)
) as Stp group by ItmKy
) as Main on Main.itmky = #Results.ItmKy

UPDATE #Results
set BufferStk = Stp.Val
from #Results inner join (
SELECT ItmMasCd.ItmKy, ItmMasCd.Val
FROM   ItmMasCd INNER JOIN #Results on #Results.ItmKy = ItmMasCd.ItmKy INNER JOIN 
             ControlCon ON ItmMasCd.ControlConKy = ControlCon.ControlConKy
WHERE (ControlCon.OurCd = 'ItmBfrStk') AND (ControlCon.TblNm = 'ItmMasCd') AND (ItmMasCd.CdKy = @LocKy) AND (ItmMasCd.isAct = 1)
) as Stp ON Stp.ItmKy = #Results.ItmKy

UPDATE #Results
set LeadTime = Stp.Val
from #Results inner join (
SELECT ItmMasCd.ItmKy, ItmMasCd.Val
FROM   ItmMasCd INNER JOIN #Results on #Results.ItmKy = ItmMasCd.ItmKy INNER JOIN 
             ControlCon ON ItmMasCd.ControlConKy = ControlCon.ControlConKy
WHERE (ControlCon.OurCd = 'LeadTime') AND (ControlCon.TblNm = 'ItmMasCd')  AND (ItmMasCd.isAct = 1)
) as Stp ON Stp.ItmKy = #Results.ItmKy

--**********************************minOrdQty **********************************************

UPDATE #Results
set MinOrdQty = Stp.Val
from #Results inner join (
SELECT ItmMasCd.ItmKy, ItmMasCd.Val
FROM   ItmMasCd INNER JOIN #Results on #Results.ItmKy = ItmMasCd.ItmKy INNER JOIN 
             ControlCon ON ItmMasCd.ControlConKy = ControlCon.ControlConKy
WHERE (ControlCon.OurCd = 'MinOrdQty') AND (ControlCon.TblNm = 'ItmMasCd')  AND (ItmMasCd.isAct = 1)
) as Stp ON Stp.ItmKy = #Results.ItmKy



UPDATE #Results
set CalcPOQty = SalesForPO * (case when LeadTime / 30 = 0 THEN 1 else  LeadTime / 30 END ) - StkInHand - PendPOQty + PendSlsOrdQty + BufferStk

UPDATE #Results
set CalcPOQty = 0
where CalcPOQty < 0

UPDATE #Results 
set ProcurPlnQty = case when CalcPOQty = 0 THEN 0 ELSE case when MinOrdQty > CalcPOQty THEN MinOrdQty else CalcPOQty END END

select #Results.* , Stp.Month , Stp.Year, Stp.MonthName, Stp.SaleQty 
from #Results LEFT OUTER JOIN  (
select ItmKy, DimDate.Year, DimDate.Month, DimDate.MonthName, (SUM(stp.SaleQty)) * -1 as SaleQty
from DimDate left outer join 
(SELECT DimDate.Date, (ItmQtyDtX.Qty) as SaleQty , #Results.ItmKy
FROM   ItmQtyDtX INNER JOIN
             CdMas ON ItmQtyDtX.TrnTypKy = CdMas.CdKy INNER JOIN
             DimDate ON ItmQtyDtX.EftvDt = DimDate.Date INNER JOIN 
			 #Results ON #Results.ItmKy = ItmQtyDtX.ItmKy
WHERE (ItmQtyDtX.CKy = @CKy) AND (CdMas.isCd91 = 1)  AND (ItmQtyDtX.EftvDt >= @DTEnd) AND (ItmQtyDtX.EftvDt <= @DtSt)
and ItmQtyDtX.isInventory=1
) as Stp ON DimDate.Date= Stp.Date
where  (DimDate.Date >= @DTEnd) AND (DimDate.Date <= @DtSt)
GROUP BY DimDate.Year, DimDate.Month, DimDate.MonthName ,  ItmKy
) as Stp ON Stp.ItmKy = #Results.ItmKy 

order by ItmCd, Year, Month



/*
select @PendPOQty =  sum(BalPOQty)
from(
SELECT  OH.Qty - ISNULL(GRN.GrnQty, 0) - ISNULL(POCancl.POCanclQty, 0) AS BalPOQty 
               
FROM    
                  (SELECT ItmKy, OrdDetKy, Qty , OrdDt, ReqDt
				  from OrdHdr with (NOLOCK)
INNER JOIN OrdDet WITH (nolock) ON OrdHdr.OrdKy = OrdDet.Ordky
WHERE
(OrdHdr.CKy = @CKy) AND (OrdHdr.CKy = @CKy) AND (OrdTypKy = @POTypKy) AND (OrdDet.isAct = 1) AND 
(OrdDet.isApr = 1) AND (OrdDet.IsSetOff = 0) AND (OrdHdr.IsAct = 1) and  (OrdHdr.OrdDt <= @Dt) and (OrdDet.ItmKy = @ItmKy)) as OH 
                
              
                 LEFT OUTER JOIN
                      (SELECT CdMas_1.CKy, OrdDet_1.ItmKy, OrdDet_1.Qty AS POCanclQty, OrdDetSetOff.CrOrdDetKy AS OrdDetKy
                       FROM      CdMas AS CdMas_1 WITH (nolock) INNER JOIN
                                         OrdHdr AS OrdHdr_1 WITH (nolock) ON CdMas_1.CdKy = OrdHdr_1.OrdTypKy INNER JOIN
                                         OrdDet AS OrdDet_1 WITH (nolock) ON OrdHdr_1.OrdKy = OrdDet_1.Ordky INNER JOIN
                                         OrdDetSetOff WITH (nolock) ON OrdDet_1.OrdDetKy = OrdDetSetOff.DrOrdDetKy
                       WHERE   (CdMas_1.CKy = @CKy) AND (CdMas_1.ConCd = 'OrdTyp') AND (CdMas_1.OurCd = 'POCancl') AND (OrdDet_1.isAct = 1) AND (OrdDet_1.isApr = 1) and (OrdDet_1.ItmKy = @ItmKy)) AS POCancl ON OH.OrdDetKy = POCancl.OrdDetKy LEFT OUTER JOIN
                      (SELECT OrdItmSetOff_1.OrdDetKy, SUM(ItmTrn_1.Qty) AS GrnQty
                       FROM      ItmTrn AS ItmTrn_1 WITH (nolock) INNER JOIN
                                         OrdItmSetOff AS OrdItmSetOff_1 WITH (nolock) ON ItmTrn_1.ItmTrnKy = OrdItmSetOff_1.ItmTrnKy
                       WHERE   (ItmTrn_1.isAct = 1) AND (ItmTrn_1.isApr = 1) and (ItmTrn_1.ItmKy = @ItmKy)
                       GROUP BY OrdItmSetOff_1.OrdDetKy) AS GRN ON OH.OrdDetKy = GRN.OrdDetKy
WHERE   
(OH.Qty > ISNULL(GRN.GrnQty, 0))  AND (OH.Qty - ISNULL(GRN.GrnQty, 0) - ISNULL(POCancl.POCanclQty, 0) >= 0.001)
) as Stp
*/




--select DimDate.Year, DimDate.Month, DimDate.MonthName, (SUM(stp.SaleQty)) * -1 as SaleQty,   @LstPOQty as LstPOQty , @PredPOQty as PredPOQty , @PendPOQty  as PendPOQty , @PredSlsQty as PredSlsQty
--from DimDate left outer join 
--(SELECT DimDate.Date, (ItmQtyDtX.Qty) SaleQty 
--FROM   ItmQtyDtX INNER JOIN
--             CdMas ON ItmQtyDtX.TrnTypKy = CdMas.CdKy INNER JOIN
--             DimDate ON ItmQtyDtX.EftvDt = DimDate.Date
--WHERE (ItmQtyDtX.CKy = @CKy) AND (CdMas.isCd91 = 1) AND (ItmQtyDtX.ItmKy = @ItmKy) AND (ItmQtyDtX.EftvDt >= @DTEnd) AND (ItmQtyDtX.EftvDt <= @DtSt)
--) as Stp ON DimDate.Date= Stp.Date
--where  (DimDate.Date >= @DTEnd) AND (DimDate.Date <= @DtSt)
--GROUP BY DimDate.Year, DimDate.Month, DimDate.MonthName 

drop table #Results
drop table #POGRNDet
END
GO