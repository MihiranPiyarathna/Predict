"""
Per-item SARIMA forecasts trained on monthly sales data stored in Excel.
The workbook need to contain at least these columns:
ItmKy, Year, Month, and SaleQty.

The script fits a forecast for each item key. Items with enough history use a
small SARIMA model search; sparse items fall back to a simple baseline so the
output still covers every item key.
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


@dataclass(frozen=True)
class ItemForecast:
	item_key: int
	item_code: str | None
	item_name: str | None
	method: str
	order: tuple[int, int, int] | None
	seasonal_order: tuple[int, int, int, int] | None
	aic: float | None
	series: pd.Series
	forecast: pd.DataFrame


def load_sales_data(
	excel_path: Path,
	sheet_name: str | int = 0,
) -> pd.DataFrame:
	"""Load workbook data and validate the expected columns."""

	data = pd.read_excel(excel_path, sheet_name=sheet_name)

	required_columns = {"ItmKy", "Year", "Month", "SaleQty"}
	missing_columns = required_columns.difference(data.columns)
	if missing_columns:
		raise ValueError(
			f"Missing required columns: {', '.join(sorted(missing_columns))}. "
			f"Found columns: {', '.join(map(str, data.columns))}"
		)

	data = data.copy()
	data["ItmKy"] = pd.to_numeric(data["ItmKy"], errors="coerce")
	data["Year"] = pd.to_numeric(data["Year"], errors="coerce")
	data["Month"] = pd.to_numeric(data["Month"], errors="coerce")
	data["SaleQty"] = pd.to_numeric(data["SaleQty"], errors="coerce").fillna(0.0)
	data = data.dropna(subset=["ItmKy", "Year", "Month"])
	data["ItmKy"] = data["ItmKy"].astype(int)
	data["Year"] = data["Year"].astype(int)
	data["Month"] = data["Month"].astype(int)
	return data


def load_item_sales_series(
	data: pd.DataFrame,
	item_key: int,
	trim_trailing_zeros: bool = True,
) -> tuple[pd.Series, int, pd.Series]:
	"""Build a monthly sales series for a single item key."""

	item_rows = data.loc[data["ItmKy"] == item_key].copy()
	if item_rows.empty:
		raise ValueError(f"No rows found for item key {item_key}.")

	item_rows["Date"] = pd.to_datetime(
		dict(year=item_rows["Year"], month=item_rows["Month"], day=1), errors="coerce"
	)
	item_rows = item_rows.dropna(subset=["Date"])
	series = item_rows.groupby("Date", as_index=True)["SaleQty"].sum().sort_index()
	if series.empty:
		raise ValueError(f"No monthly sales values were found for item key {item_key}.")

	full_index = pd.date_range(series.index.min(), series.index.max(), freq="MS")
	series = series.reindex(full_index, fill_value=0.0)
	series.index.name = "Month"
	series = series.astype(float)
	original_series = series.copy()

	trimmed_months = 0
	if trim_trailing_zeros and series.ne(0).any():
		last_active_position = int(series.ne(0).to_numpy().nonzero()[0][-1])
		trimmed_months = len(series) - (last_active_position + 1)
		series = series.iloc[: last_active_position + 1]

	return series, trimmed_months, original_series


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


def forecast_naive(series: pd.Series, periods: int) -> pd.DataFrame:
	"""Fallback forecast for sparse item histories."""

	last_value = float(series.iloc[-1]) if len(series) else 0.0
	future_index = pd.date_range(series.index[-1] + pd.offsets.MonthBegin(1), periods=periods, freq="MS")
	frame = pd.DataFrame(
		{
			"forecast": [last_value] * periods,
			"lower_ci": [last_value] * periods,
			"upper_ci": [last_value] * periods,
		},
		index=future_index,
	)
	frame.index.name = "Month"
	return frame


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


def item_metadata(rows: pd.DataFrame) -> tuple[str | None, str | None]:
	"""Extract stable item labels for reporting."""

	item_code = None
	item_name = None
	if "ItmCd" in rows.columns:
		codes = rows["ItmCd"].dropna().astype(str).unique()
		if len(codes):
			item_code = codes[0]
	if "ItmNm" in rows.columns:
		names = rows["ItmNm"].dropna().astype(str).unique()
		if len(names):
			item_name = names[0]
	return item_code, item_name


def forecast_item(
	data: pd.DataFrame,
	item_key: int,
	periods: int,
	seasonal_period_override: int | None,
	trim_trailing_zeros: bool,
) -> ItemForecast:
	"""Forecast one item key using SARIMA when enough history exists."""

	item_rows = data.loc[data["ItmKy"] == item_key].copy()
	item_code, item_name = item_metadata(item_rows)
	series, trimmed_months, original_series = load_item_sales_series(
		data,
		item_key,
		trim_trailing_zeros=trim_trailing_zeros,
	)
	seasonal_period = seasonal_period_for_history(len(series), seasonal_period_override)

	method = "sarima"
	order: tuple[int, int, int] | None = None
	seasonal_order: tuple[int, int, int, int] | None = None
	aic: float | None = None

	use_sarima = len(series) >= 6 and series.ne(0).any()
	if use_sarima:
		try:
			result = fit_best_sarima(series, seasonal_period)
			forecast_frame = forecast_sales(result.model_fit, periods)
			order = result.order
			seasonal_order = result.seasonal_order
			aic = result.aic
		except Exception:
			use_sarima = False

	if not use_sarima:
		method = "naive"
		forecast_frame = forecast_naive(original_series if len(original_series) else series, periods)

	output = build_forecast_table(series if len(series) else original_series, forecast_frame)
	return ItemForecast(
		item_key=item_key,
		item_code=item_code,
		item_name=item_name,
		method=method,
		order=order,
		seasonal_order=seasonal_order,
		aic=aic,
		series=series,
		forecast=output,
	)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Train per-item SARIMA forecasts from an Excel workbook.")
	parser.add_argument(
		"--excel",
		type=Path,
		default=Path("sales since 01.06.2025 to 16.06.2026.xlsx"),
		help="Path to the Excel workbook containing monthly sales data.",
	)
	parser.add_argument("--sheet", default=0, help="Excel sheet name or zero-based sheet index.")
	parser.add_argument("--periods", type=int, default=3, help="Number of future months to forecast.")
	parser.add_argument(
		"--item-key",
		type=int,
		default=None,
		help="Forecast a single item key instead of all item keys.",
	)
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
		default=Path("sarima_item_forecast.csv"),
		help="CSV file to save the forecast table.",
	)
	return parser.parse_args()


def forecast_items(
	data: pd.DataFrame,
	periods: int,
	item_key: int | None,
	seasonal_period_override: int | None,
	trim_trailing_zeros: bool,
) -> pd.DataFrame:
	"""Forecast one or many items and return a combined output table."""

	if item_key is not None:
		item_keys = [item_key]
	else:
		item_keys = sorted(data["ItmKy"].dropna().astype(int).unique().tolist())

	rows: list[pd.DataFrame] = []
	for key in item_keys:
		item_result = forecast_item(
			data,
			key,
			periods,
			seasonal_period_override,
			trim_trailing_zeros,
		)
		frame = item_result.forecast.copy()
		frame.insert(0, "ItmKy", item_result.item_key)
		frame.insert(1, "ItmCd", item_result.item_code)
		frame.insert(2, "ItmNm", item_result.item_name)
		frame.insert(3, "Method", item_result.method)
		frame["Order"] = [str(item_result.order)] * len(frame)
		frame["SeasonalOrder"] = [str(item_result.seasonal_order)] * len(frame)
		frame["AIC"] = item_result.aic
		rows.append(frame)

	return pd.concat(rows, ignore_index=True)


def main() -> None:
	warnings.filterwarnings("ignore")

	args = parse_args()
	sheet_name: str | int = int(args.sheet) if str(args.sheet).isdigit() else args.sheet

	data = load_sales_data(
		args.excel,
		sheet_name=sheet_name,
	)
	output = forecast_items(
		data,
		periods=args.periods,
		item_key=args.item_key,
		seasonal_period_override=args.seasonal_period,
		trim_trailing_zeros=not args.keep_zero_months,
	)

	method_counts = output["Method"].value_counts().to_dict()
	print("Items forecasted:", output["ItmKy"].nunique())
	print("Forecast rows:", len(output))
	print("Method counts:", method_counts)
	print("\nForecast preview:")
	preview = output if len(output) <= 20 else output.head(20)
	print(preview.to_string(index=False, float_format=lambda value: f"{value:,.2f}" if isinstance(value, (int, float)) else str(value)))
	if len(output) > len(preview):
		print(f"... {len(output) - len(preview)} more row(s) saved to CSV")

	if args.output:
		output.to_csv(args.output, index=False)
		print(f"\nSaved forecast to {args.output}")


if __name__ == "__main__":
	main()
