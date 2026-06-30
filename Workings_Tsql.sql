select AdrKy, adrnm from AdrMas where adrNm like '%test%customer%' and cky = '1237'

select AccKy,AccCd,  AccNm from AccMas where AccNm like '%test%customer%' and cky = '1237'
select AccKy,AccCd,  AccNm from AccMas where AccCd = '100263' and cky = '1237'

select UsrKy, UsrNm from UsrMas where UsrNm like '%mihiran%'
select UsrKy, UsrNm from UsrMas where Usrky = 28 -- Admin
