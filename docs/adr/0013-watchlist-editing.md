# 0013. Watchlist editing: optimistic, serialised, rollback to confirmed
Date: 2026-11-08
Status: Accepted (Tech Lead approved all QUESTIONS.md defaults, 2026-11-08)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
`putWatchlist` replaces the whole list (max 20, no duplicates). The UI must feel instant but stay correct when a save fails.

## Decision
- Edits are validated locally by `WatchlistRules` (same rules as the server) and applied optimistically.
- One save in flight; later edits are coalesced into the next save of the latest list.
- On failure the list rolls back to the last **server-confirmed** list and a snackbar explains it (local rejections such as duplicates do not claim a rollback).
- If the server returns a different list than sent and the user did not edit meanwhile, the server's list wins.
- A watchlist that cannot be read is an error, never an empty list (an empty list could later overwrite the real one).

## Consequences
+ No lost updates, no interleaved writes. − One failed save discards several rapid edits (Q9).
