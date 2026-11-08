# candles

Candle data for the chart in the ticket. ADR-0017. Drawing lives in the design system (`PulseCandleChart`).

## Pieces
- `domain/entities/candle.dart`: `Candle`, `CandleRange` (`1D` 5-min, `1W` hourly, `1M` daily).
- `data/`: `CandleModel` (tolerant), `CandleRepositoryImpl` (sorted oldest first, duplicate timestamps keep the last).
  A bar that cannot be drawn truthfully (non-positive low, open/close outside low..high) is skipped, never "fixed".
- `presentation/cubit/candles_cubit.dart`: per symbol; a slow response for an old range cannot overwrite a newer one;
  `applyLivePrice` folds the live price into the newest bar and ignores ticks after the cubit is closed.
- `presentation/widgets/candle_section.dart`: range selector, chart, legend, loading / empty / failure states.

## Behaviour worth knowing
- The server builds the history on each request as a seeded walk ending at the current price, so it is a snapshot. Only the
  last bar follows live prices; a new bar is **not** started when a time bucket ends.
- Direction is shape-coded (hollow = rising, filled = falling), not colour only.

## Tests
`test/features/candles/`, `packages/pulse_design_system/test/pulse_candle_chart_test.dart`.
