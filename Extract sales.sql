DECLARE 
@cky int = 1237,
@DtSt DATE = CURRENT_DATE,
@DtEnd DATE = '01/01/2025'
-- @DtEnd DATE = '01/01/2026'

CREATE TABLE #Results (
    ItmKy bigint,
    ItmCd varchar(100),
    ItmNm varchar(150),
)
INSERT INTO #Results (ItmKy, Itmcd, ItmNm) (select ItmKy, Itmcd, ItmNm from ItmMas where cky= @cky and isAct=1 and IsAlwTrn = 1)
-- select * from #Results

select ItmKy, ItmCd, ItmNm, DimDate.Year, DimDate.Month, DimDate.MonthName, -SUM(stp.SaleQty) as SaleQty
from DimDate left outer join 
(SELECT DimDate.Date, (ItmQtyDtX.Qty) as SaleQty, #Results.ItmKy , #Results.ItmCd, #Results.ItmNm
FROM   ItmQtyDtX INNER JOIN
             CdMas ON ItmQtyDtX.TrnTypKy = CdMas.CdKy INNER JOIN
             DimDate ON ItmQtyDtX.EftvDt = DimDate.Date INNER JOIN 
			 #Results ON #Results.ItmKy = ItmQtyDtX.ItmKy
WHERE (ItmQtyDtX.CKy = @CKy) AND (CdMas.isCd91 = 1)  AND (ItmQtyDtX.EftvDt >= @DTEnd) AND (ItmQtyDtX.EftvDt <= @DtSt)
and ItmQtyDtX.isInventory=1
) as Stp ON DimDate.Date= Stp.Date
where  (DimDate.Date >= @DTEnd) AND (DimDate.Date <= @DtSt)
GROUP BY DimDate.Year, DimDate.Month, DimDate.MonthName ,  ItmKy, ItmCd, ItmNm

DROP table #Results;


-- 