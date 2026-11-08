# 0021. Units and order availability
Date: 2026-11-08
Status: Accepted (assumed default — see QUESTIONS.md Q16)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Quantities were bare numbers. Users need to know "10 of what", how much USD they can spend when buying and how much they can sell, while `lotSize`/`tickSize` still decide what is valid.

## Decision
- `Instrument.unit`: the server sends none, so the app derives it: `share` (shown "سهم") for stocks/ETFs, the coin ticker for crypto (`BTC-USD` → `BTC`). A server-sent `unit` wins. The type `EQUITY` is now recognised as a stock (it was `other`).
- The ticket shows the unit in the quantity label ("تعداد (BTC)") — a label, not a suffix, because Material hides a suffix on an empty unfocused field.
- **Availability line on the ticket** (server account, SSOT-01): when buying — USD available, the most affordable quantity and the current holding; when selling — the amount that can be sold or "nothing to sell". A "max" button fills the quantity field.
- `MaxOrderQuantity` (pure, `Decimal` only): buy = `floor(cash / (price × lot)) × lot` at the ask (or last); sell = holding rounded down to a lot. No price ⇒ no maximum is shown (never a guess). `lotSize`/`tickSize` validation (VAL rules) is unchanged and still the gate for submission.
- Holdings rows and order cards show quantity with the unit and lot-scale digits.

## Consequences
+ Clear amounts; the max can never exceed lot or cash. − A market buy fills at the touch price at execution time, so "max" is an estimate (a limit order's price changes the real cost).
