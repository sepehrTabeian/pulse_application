# 0017. Candle chart
Date: 2026-11-08
Status: Accepted (Tech Lead requested the chart, "Could #9")
Deciders: Tech Lead, Staff Flutter Engineer

## Context
`getCandles(symbol, range)` returns `{"candles":[{"t","o","h","l","c","v"}]}` for `1D` (78 five-minute bars), `1W` (35 hourly) and `1M` (22 daily). Charts must not become a way to show wrong prices.

## Decision
- Feature `candles` with the usual layers: `Candle` entity (Decimal), `CandleReader` role interface, `CandleModel` (tolerant parsing), `CandleRepositoryImpl` (retrying read, sorted oldest-first, duplicate timestamps keep the last bar).
- A bar that cannot be drawn truthfully (non-positive low, `open`/`close` outside `[low, high]`, missing time/price) is skipped and logged, never "fixed".
- `CandlesCubit` per symbol; a slow response for an old range can never overwrite a newer one.
- Drawing lives in the design system (`PulseCandleChart`), independent of the app. Exact numbers stay `Decimal` in the app; they are converted to plain numbers ONLY at the chart edge for pixel math (display-only).
- Accessibility: direction is shape-coded, not colour-only (rising = hollow, falling = filled), with a legend, a spoken summary, and tap/drag to read exact OHLC of a bar.
- Geometry (`CandleChartGeometry`) is pure and unit-tested: flat markets, a single bar, empty data, thousands of bars, edge touches.

## Consequences
+ Small, testable, no charting dependency. − No zoom/pan, no volume bars.

## Amendment (2026-11-08): live last bar
The server generates the history per request (a seeded walk ending at the current price), so it is a snapshot. While a ticket is open, `CandlesCubit.applyLivePrice` folds each live price into the newest bar (close = price, high/low widened); no new bar is started when a time bucket ends, and the history is reloaded only by changing the range or reopening the ticket.
