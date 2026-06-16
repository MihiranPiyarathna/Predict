Per-item SARIMA model forecasts trained on monthly sales data stored in Excel.
The workbook need to contain at least these columns:
ItmKy, Year, Month, and SaleQty.

The script & the SARIMA model fits a forecast for each item key. Items with enough history use a
small SARIMA model search; sparse items fall back to a simple baseline so the
output still covers every item key.

ARIMA can work well for sales prediction, but it depends a lot on the nature of your sales data
and what you're trying to forecast. It tends to do well when your sales history has clear patterns:
a fairly stable trend, no abrupt structural breaks, and enough historical data points 
(ARIMA generally needs at least 50, ideally 100+, observations to estimate parameters reliably). 

It's also a solid choice when you're forecasting a single time series without much need to 
incorporate external factors, since plain ARIMA only looks at the series' own past values.
Where it struggles is with seasonality unless you use the seasonal variant, SARIMA, 
which adds seasonal terms to handle things like holiday spikes or weekly cycles.
