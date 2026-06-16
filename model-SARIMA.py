"""
SARIMA model trained on monthly sales data stored in Excel.
The workbook need to contain at least these columns:
Year, Month, and SaleQty.

The script aggregates all item rows into a single monthly sales
series, fits a small SARIMA model search, and prints a forecast for the next
few months.
"""

from __future__ import annotations

import argparse
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pandas as pd
from statsmodels.tsa.statespace.sarimax import SARIMAX


@dataclass(frozen=True)
class SarimaResult:
	order: tuple[int, int, int]
	seasonal_order: tuple[int, int, int, int]
	aic: float
	model_fit: object


def load_monthly_sales_series(
	excel_path: Path,
	sheet_name: str | int = 0,
	trim_trailing_zeros: bool = True,
) -> tuple[pd.Series, int]:
	"""Load and aggregate sales into a monthly time series."""

	data = pd.read_excel(excel_path, sheet_name=sheet_name)

	required_columns = {"Year", "Month", "SaleQty"}
	missing_columns = required_columns.difference(data.columns)
	if missing_columns:
		raise ValueError(
			f"Missing required columns: {', '.join(sorted(missing_columns))}. "
			f"Found columns: {', '.join(map(str, data.columns))}"
		)

	monthly = data.loc[:, ["Year", "Month", "SaleQty"]].copy()
	monthly["Year"] = pd.to_numeric(monthly["Year"], errors="coerce")
	monthly["Month"] = pd.to_numeric(monthly["Month"], errors="coerce")
	monthly["SaleQty"] = pd.to_numeric(monthly["SaleQty"], errors="coerce").fillna(0.0)
	monthly = monthly.dropna(subset=["Year", "Month"])

	monthly["Year"] = monthly["Year"].astype(int)
	monthly["Month"] = monthly["Month"].astype(int)
	monthly["Date"] = pd.to_datetime(
		dict(year=monthly["Year"], month=monthly["Month"], day=1), errors="coerce"
	)
	monthly = monthly.dropna(subset=["Date"])

	series = monthly.groupby("Date", as_index=True)["SaleQty"].sum().sort_index()
	if series.empty:
		raise ValueError("No monthly sales values were found in the workbook.")

	full_index = pd.date_range(series.index.min(), series.index.max(), freq="MS")
	series = series.reindex(full_index, fill_value=0.0)
	series.index.name = "Month"
	series = series.astype(float)

	trimmed_months = 0
	if trim_trailing_zeros and series.ne(0).any():
		last_active_position = int(series.ne(0).to_numpy().nonzero()[0][-1])
		trimmed_months = len(series) - (last_active_position + 1)
		series = series.iloc[: last_active_position + 1]

	return series, trimmed_months


def seasonal_period_for_history(history_length: int, requested_period: int | None = None) -> int:
	"""Pick a seasonal period that the available history can support."""

	if requested_period is not None:
		if requested_period < 2:
			raise ValueError("seasonal_period must be at least 2.")
		return requested_period

	if history_length >= 24:
		return 12
	if history_length >= 12:
		return 6
	if history_length >= 8:
		return 4
	if history_length >= 6:
		return 3
	return 0


def candidate_models(seasonal_period: int) -> Iterable[tuple[tuple[int, int, int], tuple[int, int, int, int]]]:
	"""Generate a small set of SARIMA candidates."""

	orders = [(0, 1, 1), (1, 1, 0), (1, 1, 1), (0, 1, 2)]
	if seasonal_period <= 0:
		return ((order, (0, 0, 0, 0)) for order in orders)

	seasonal_orders = [
		(0, 0, 0, seasonal_period),
		(1, 0, 0, seasonal_period),
		(0, 0, 1, seasonal_period),
		(1, 0, 1, seasonal_period),
	]
	return ((order, seasonal_order) for order in orders for seasonal_order in seasonal_orders)


def fit_best_sarima(series: pd.Series, seasonal_period: int) -> SarimaResult:
	"""Fit the best model from a small SARIMA grid search."""

	if len(series) < 6:
		raise ValueError("At least 6 monthly observations are required for a forecast.")

	best_result: SarimaResult | None = None
	for order, seasonal_order in candidate_models(seasonal_period):
		try:
			model = SARIMAX(
				series,
				order=order,
				seasonal_order=seasonal_order,
				trend="n",
				enforce_stationarity=False,
				enforce_invertibility=False,
			)
			fitted = model.fit(disp=False)
		except Exception:
			continue

		result = SarimaResult(order=order, seasonal_order=seasonal_order, aic=float(fitted.aic), model_fit=fitted)
		if best_result is None or result.aic < best_result.aic:
			best_result = result

	if best_result is None:
		raise RuntimeError("Unable to fit any SARIMA candidate to the supplied sales series.")

	return best_result


def forecast_sales(model_fit: object, periods: int) -> pd.DataFrame:
	"""Return a forecast table with confidence intervals."""

	forecast = model_fit.get_forecast(steps=periods)
	frame = forecast.summary_frame()
	frame = frame.rename(
		columns={
			"mean": "forecast",
			"mean_ci_lower": "lower_ci",
			"mean_ci_upper": "upper_ci",
		}
	)
	return frame.loc[:, ["forecast", "lower_ci", "upper_ci"]]


def build_forecast_table(series: pd.Series, forecast_frame: pd.DataFrame) -> pd.DataFrame:
	"""Combine forecast values with future month labels."""

	future_index = pd.date_range(series.index[-1] + pd.offsets.MonthBegin(1), periods=len(forecast_frame), freq="MS")
	output = forecast_frame.copy()
	output.insert(0, "Month", future_index)
	output["forecast"] = output["forecast"].clip(lower=0.0)
	output["lower_ci"] = output["lower_ci"].clip(lower=0.0)
	output["upper_ci"] = output["upper_ci"].clip(lower=0.0)
	return output


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Train a SARIMA sales forecast from an Excel workbook.")
	parser.add_argument(
		"--excel",
		type=Path,
		default=Path("sales since 01.06.2025 to 16.06.2026.xlsx"),
		help="Path to the Excel workbook containing monthly sales data.",
	)
	parser.add_argument("--sheet", default=0, help="Excel sheet name or zero-based sheet index.")
	parser.add_argument("--periods", type=int, default=3, help="Number of future months to forecast.")
	parser.add_argument(
		"--seasonal-period",
		type=int,
		default=None,
		help="Override the seasonal period. Defaults to 12 when enough history exists.",
	)
	parser.add_argument(
		"--keep-zero-months",
		action="store_true",
		help="Keep trailing all-zero months instead of trimming them before fitting.",
	)
	parser.add_argument(
		"--output",
		type=Path,
		default=Path("sarima_forecast.csv"),
		help="Optional CSV file to save the forecast table.",
	)
	return parser.parse_args()


def main() -> None:
	warnings.filterwarnings("ignore")

	args = parse_args()
	sheet_name: str | int = int(args.sheet) if str(args.sheet).isdigit() else args.sheet

	series, trimmed_months = load_monthly_sales_series(
		args.excel,
		sheet_name=sheet_name,
		trim_trailing_zeros=not args.keep_zero_months,
	)
	seasonal_period = seasonal_period_for_history(len(series), args.seasonal_period)
	if trimmed_months:
		print(f"Trimmed {trimmed_months} trailing zero month(s) before fitting.")
	if seasonal_period == 0:
		print("History is too short for seasonal terms; using a non-seasonal ARIMA fallback.")

	result = fit_best_sarima(series, seasonal_period)
	forecast_frame = forecast_sales(result.model_fit, args.periods)
	output = build_forecast_table(series, forecast_frame)

	print("Series length:", len(series))
	print("Date range:", series.index.min().date(), "to", series.index.max().date())
	print("Best model order:", result.order)
	print("Best seasonal order:", result.seasonal_order)
	print("AIC:", round(result.aic, 2))
	print("\nForecast:")
	print(output.to_string(index=False, float_format=lambda value: f"{value:,.2f}"))

	if args.output:
		output.to_csv(args.output, index=False)
		print(f"\nSaved forecast to {args.output}")


if __name__ == "__main__":
	main()
