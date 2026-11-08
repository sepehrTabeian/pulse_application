---
name: decision-protocol
description: How to present an architectural/product decision to the Tech Lead before acting. Use whenever a choice (state management, retries, persistence, UX behavior, package) is not already recorded in an ADR.
---

# Decision protocol

For each decision, output exactly this block, then stop and wait for the lead:

```
### D<n>: <decision title>
**Why it matters:** <impact on money safety / UX / testability / time>
**Options:**
1. <A> — pros / cons
2. <B> — pros / cons
3. <C> — pros / cons
**Edge cases:** <bullets: network, ordering, lifecycle, halted instrument, precision, concurrency>
**Recommendation:** <option + one-sentence reason + what would change my mind>
**Question for you:** <only what cannot be derived from code/README>
```

Rules:
- Check `docs/adr/` and `pulse_api` source first; don't ask what the code answers.
- Group related decisions; max ~5 per message.
- Mark time cost (min) for each option — build window is 80 minutes.
- After approval, record in an ADR (skill `adr-writing`).
