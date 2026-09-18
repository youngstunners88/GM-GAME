# Content Calendar — Smoke Content Engine

The running plan. This is what makes the engine *repeatable*: a backlog of
drops, a cadence, and a board that tracks each drop through its lifecycle.
Groom this with the `content-calendar` skill; scaffold a drop with `drop-runner`.

## Cadence (default — founder confirms)

| Slot | What | Format | Owner |
|------|------|--------|-------|
| Weekly anchor | The week's main story clip | `format-hype-30s` | Astra + Claude |
| Mid-week hero | Rewatchable peak moment | `format-hero-10s` | cut from anchor or dedicated 2.5 |
| Filler / reactive | Meme still or reply-bait | `format-still-post` / `format-x-thread` | Claude, brand-locked |

Rule of thumb: **one promise per drop**, never spam the same 30s more than
twice without a new hook (see `distribution/CONTEXT.md`).

## Backlog (groom top-down; highest = next)

| Priority | Working title | Format | Hook seed | Status |
|----------|---------------|--------|-----------|--------|
| 1 | Bong-party teaser | hype-30s | "every Friday the smoke rings up on Solana" | in flight → drop 001 (scripted) |
| 2 | Wrapped-Smoke NFT reveal | hype-30s | "your NFT is your ticket in" | idea |
| 3 | SOL-reward moment | hero-10s | reward flash at the party peak | idea |

## Drop board (live lifecycle state)

Lifecycle: `idea → briefed → scripted → shots → rendering → assembled → scheduled → live → analyzed → archived`

| # | Slug | Format | State | Target date | Master | Notes |
|---|------|--------|-------|-------------|--------|-------|
| 001 | bong-party-teaser | hype-30s | assembled | TBD | 30s + 10s hero in output/ | Seedance 2 (3 clips, ~$3.75); hero 9–19s; 2.5 unspent; awaiting founder review → distribution |

## How a drop flows through this board

1. `content-calendar` picks the next backlog item and confirms the format.
2. `drop-runner` scaffolds `drops/NNN_slug/` and adds a board row at `briefed`.
3. `astra-lead` fills the brief + locks the hook → state `scripted`.
4. `script-lab` writes final + shot list → state `shots`.
5. `seedance-pipeline` renders + assembles → `rendering` → `assembled`.
6. `distribution-smoke` writes posts + schedule → `scheduled` → `live`.
7. Analytics captured → `analyzed`; folder moves to `/archive` → `archived`.

Every state change updates BOTH this board and `STATUS.md`.

## Recurring anchors (do not lose these)

- Weekly bong party = the ecosystem's heartbeat. Every anchor drop should be
  able to point at "this Friday."
- Launch-week special cadence lives in `distribution/CONTEXT.md`.
