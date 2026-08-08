# Grok 4.5 brief — title/UI readability hierarchy + control-instruction panel

You are the design-identity advisor for **Lil Blunt Adventure** (Godot 4.3
retro 16-bit chill 2D platformer, HTML5 web export, played increasingly on
phones held at normal arm's length). Keep this SHORT and concrete.

## Problem 1 — titles/UI too small on a phone

Current main menu (base res 1280x720, stretched to fit, so on a phone these
px sizes shrink to the physical screen):
- Title "LIL BLUNT / THE SMOKE REALM" — font size **48**
- Subtitle "THE SMOKE REALM" — font **24** (note: title already includes the
  subtitle text on a second line, so there is some redundancy)
- PLAY / CONTINUE / QUIT buttons — font **28**, in a 400px-wide centered
  column
- A secondary column of ~9 smaller buttons (ONBOARDING, LEADERBOARD, ORACLE,
  CONNECT RABBY, etc.) at font **20**, 300x46 each, bottom-left corner
- Background is a dark green art plate; text is near-white.

I need a **hierarchy**, not "make everything bigger" (a wall of giant text
is as bad as tiny text). Give me:
1. A recommended **font-size ladder** (title / subtitle / primary buttons /
   secondary buttons) as concrete px values at 1280x720 base, ordered so the
   hierarchy is obvious at arm's length on a phone.
2. One sentence on **contrast/legibility** — do the near-white-on-dark-green
   values need a shadow/outline/plate to stay readable over busy art? Yes/no
   + the minimal fix.
3. The single **most important** readability fix to do first if I only did
   one thing.

## Problem 2 — control-instruction panel (first-run + always-available)

New players don't know what to press. I'm adding a dismissible, on-brand
instruction surface that shows **both** keyboard AND touch controls. It must
NOT be a wall of text and must not block play.

Give me:
1. A tight **copy block** for the panel — the actual short lines of text to
   display, covering: move, jump (+ double jump), attack, dash/sprint,
   interact/climb — worded for BOTH "keyboard" and "tap" in Lil Blunt's
   chill, friendly voice (he's a laid-back weed nugget, positive and cool,
   never aggressive or stoner-cliché).
2. **Layout principles** (3-4 bullets): where it appears, how it's dismissed,
   how it stays available later, how to show kbd-vs-touch without doubling
   the text length.
3. Whether it should **auto-show once** on first run or be opt-in from the
   menu — recommend one.

On-brand = chill, warm, confident, blockchain-flavored but not shilly. Do
not invent lore or new features.
