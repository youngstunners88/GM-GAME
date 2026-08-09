# Founder art drop-in paths — Blaze Rush B1/B2/B6

Three images the founder sent in chat render into the conversation but were
never written to disk (pasted-image uploads don't land as files the way an
attached `.md` or `.mp3` does — confirmed by searching the whole container).
So there are no source pixels for these three yet, and nothing was
re-drawn from a description — that is exactly how the Lil Blunt logo got
replaced with the wrong art previously.

The code in `src/dashmode/blaze_rush.gd` already checks for each file with
`ResourceLoader.exists()` and falls back to the current art when absent. Drop
the file at the path below, run `godot --headless --import` once, and it
appears in the game with **no code change**.

| File | Replaces | What it is |
|---|---|---|
| `blaze_diamond_correct.png` | the blue gem token art | the correct flaming-diamond mark — brilliant-cut diamond wrapped in orange flame, on a transparent/circular field |
| `enter_the_blaze_rush.png` | (nothing today — new) | the "ENTER THE BLAZE RUSH!" wordmark, shown briefly on entering a run |
| `now_look_smoke_lounge.png` | `br_smoke_lounge_car.png` in the purple band | "NOW LOOK FOR THE SMOKE LOUNGE" — replaces the lowrider banner outright |

## Already wired, no drop-in needed

Two other images from the same batch turned out to already be in the repo —
found by direct comparison, not re-created:

- The Robin Hood x Smoke Lounge card = `src/assets/art/robinhood_smokelounge.png`,
  byte-identical to the unreferenced `br_robinhood.png`. Now placed in the Blaze
  band at the slot GoldMine vacated (B3).
- The current lowrider banner half of `now_look_smoke_lounge.png` =
  `src/assets/art/smoke_lounge_banner.png`, confirming that art *is*
  `br_smoke_lounge_car.png` — the B6 "replace entirely" target.

## Format

PNG, transparent background where the art is a circular/free-form mark
(`blaze_diamond_correct.png`), opaque otherwise. No white outline baked in —
the game's own compositing adds no ring, so one in the source file will show.
