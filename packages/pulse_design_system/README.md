# pulse_design_system

Independent Flutter package (own `pubspec.yaml`) with the Pulse look and the reusable widgets. ADR-0004. It knows
nothing about trading, `pulse_api` or the app's features.

## Public API (`lib/pulse_design_system.dart`)

| Export | What |
|---|---|
| `PulseTheme.light()` / `.dark()` | Material 3 themes (seed colour, Vazirmatn font family, app bar, card, navigation bar, input and button shapes) |
| `PulseSemanticColors` | Theme extension: `priceUp`, `priceDown`, `stale`, `halted`, `crypto` |
| `PulseSpacing`, `PulseRadii`, `PulseMotion` | Spacing and shape tokens, 48 dp minimum touch target |
| `PulsePriceChange` | Price change with icon + sign + semantics, never colour only |
| `PulseStatusBanner` | Info / warning / error banner with an info button |
| `PulsePrimaryButton` | Button with a pending state |
| `PulseLoadingView`, `PulseMessageView` | Loading, empty and error states |
| `showPulseInfoSheet` | Explanation bottom sheet |
| `PulseAssetAvatar` | Round badge with the first letters of a symbol |
| `PulseCandleChart` | Candle chart (geometry is pure and unit-tested) |

## Rules
- Feature code must use these tokens, not raw `Colors.*` or hex colours (`COLOR-01`).
- The font file ships with the **app** (`assets/fonts`, family `Vazirmatn`); the package only references the family name.
- Direction (up/down) is never conveyed by colour alone.
- Add a new widget here only if at least two features need it; otherwise keep it in the feature.

## Tests
```bash
cd packages/pulse_design_system && flutter test
```
