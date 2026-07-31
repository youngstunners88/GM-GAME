# Grok 4.5 brief — mobile-native control scheme for a chill 2D platformer

You are the game-feel / design-identity advisor for **Lil Blunt Adventure**,
a Godot 4.3 retro 16-bit 2D side-scrolling platformer. Hero is Lil Blunt, a
small, cute, chill weed-nugget character (NOT aggressive). The game ships as
an HTML5 web export, primarily played on **itch.io** — increasingly on
phones and tablets in a mobile browser, landscape orientation.

Keep this SHORT and specific — a scheme I can implement, not an essay.

## The actual current state (real, from the code)

Movement/abilities the player has:
- Move left/right, jump, **double jump**, sprint, dash, interact (ladders /
  forges / doors), and **attack** (this is critical — attack is the input
  that throws the weapon AND redirects the Boss 2 orbs; a fight is unwinnable
  without a reliable attack).
- Blaze Mode (temporary speed/jump buff), climb ladders (needs up/down).

Current touch layout (what exists today):
- Left ~40% of screen = a "joystick" zone that is actually **digital** —
  it only reads sign(x), so it's really just left/right, no analog ramp, and
  the on-screen joystick knob never visually follows the thumb.
- Right side = a vertical stack of square buttons: JUMP (top), SPRINT,
  DASH, INTERACT (bottom), plus an ATK button offset to the left of the
  stack. Buttons are ~80px squares.
- Up/down for ladders has **no touch control at all** right now.

Design constraints:
- Landscape only on mobile (`window/handheld/orientation` is landscape).
- Base resolution 1280x720, `stretch/mode=canvas_items`, `aspect=expand`.
- This is a CHILL game — controls should feel relaxed and forgiving, not
  twitchy/hardcore. Generous hit targets over precision.

## What I need from you (answer all four, briefly)

1. **Thumb-zone layout** for landscape phone/tablet. Left thumb and right
   thumb: exactly which controls go where, and roughly what size/position
   (in % of screen or px at 1280x720). Account for: move L/R, jump, attack,
   AND the currently-missing up/down (ladders) and dash/sprint. If some
   actions should be combined or contextual (e.g. up/down only appears near
   a ladder), say so.
2. **ATK placement specifically** — it's the most-pressed combat input and
   currently a small offset button. Where should it live for a right-thumb
   player, and how big?
3. **Three concrete "don'ts"** — the top things to AVOID that come from
   naively shrinking PC controls onto a touchscreen (e.g. tiny buttons under
   the thumb's own shadow, controls in the safe-area notch region, etc.).
4. **Analog vs digital movement** for THIS game — is a real analog thumb
   zone worth it for a chill platformer, or is clean digital left/right +
   a good deadzone actually better here? Give a recommendation, not both.

Do not redesign the game or add mechanics. This is a control-surface layout
brief only.
