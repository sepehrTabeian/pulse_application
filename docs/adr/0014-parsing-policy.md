# 0014. Defensive parsing policy
Date: 2026-11-08
Status: Accepted (Tech Lead, Q1)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The server may send null, a different type, or omit keys. One bad item must never crash the app or hide the whole list.

## Decision
- All external JSON is read through `JsonReader` (no `as`, no `!`); parsing never throws a `TypeError`.
- Models mirror the wire and never throw while parsing; business validity is decided in `toEntity()` and reported as `ParsingException`.
- **Lists: skip-and-log.** An invalid item is dropped with a warning; the rest is shown (instruments, positions, snapshot items).
- **Safety defaults:** missing `tradable` ⇒ NOT tradable; unknown order `status` ⇒ `unknown` (never assumed filled); missing `cash` or watchlist `symbols` ⇒ error (never shown as 0 / empty, because an empty list could later be written back and wipe the user's list); `tickSize`/`lotSize` ≤ 0 rejected; decimal text > 40 chars or with exponent rejected.
- Stream: malformed/unknown messages are dropped; they never close the stream.

## Consequences
+ A broken instrument cannot take the screen down. − A genuinely valid instrument whose field the server omits is hidden (logged).

## Tests
`json_reader_test`, model tests, price-message parser tests, and contract tests against the real simulator (zero instruments skipped).
