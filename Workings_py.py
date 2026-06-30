# def greet():
#     print("Hello")

# if __name__ == "__main__":
#     greet()

# name = __name__
# print(name)

import pandas as pd
# import os
import xlsxwriter
# os.access(os.getcwd(), os.W_OK)

df = pd.read_excel('Link3 Sales History Data 29.06.2026.xlsx', "Sheet1")
df = df.rename(columns={"Inv Date":"Date", 'Qty':'SaleQty'})

df['Date'] = pd.to_datetime( df['Date'])
df = df.assign(Year = df['Date'].dt.year, 
               Month = df['Date'].dt.month)
monthly_sales = df.groupby(['ItmKy','ItmCd','ItmNm','Year','Month'], as_index=False)[
    'SaleQty'].sum()

monthly_sales.to_excel('Link3 Sales History Data 29.06.2026_.xlsx')

############
