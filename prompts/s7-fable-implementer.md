@include prompts/_s7_facts.md

# YOUR ROLE: Fable-5 — lead implementer (Godot 4.3 GDScript)

Give concrete, code-shaped guidance, each with the ONE failure mode + minimal fix:

## T1 Readable text
A reusable helper to make every vault Label big + outlined. Give exact Godot
4.3 calls (font_size, font_outline_color, outline_size) and a sensible minimum
mobile size. Should I set these per-label or via a Theme? Recommend one.

## T2 Usable diamond utility (big buttons)
Turn the clerk text-adjuster into an OBVIOUS large-button flow (Button nodes in
a VBoxContainer/CanvasLayer) for: show holdings, STAKE amount +/- (0..owned),
CRUSH amount +/- (0..stack), CONFIRM. Keep it headlessly testable (logic in
GoldMineSystem; buttons just call it). Give the node layout + how buttons stay
big/tappable on mobile web. Mira Voss art (portrait) shown beside the panel.

## T3 S2 long-range + chase
`_throw_shards` speed 170..250, lifetime? Diamonds fizzle before crossing the
arena. Give the projectile speed + lifetime so a shot reaches a player across a
~1200px arena, and confirm the boss's horizontal pursuit floor is adequate.
State the numeric change.

## T4 Blunt slightly bigger
Add a render-scale to LilBluntVisual (~1.2-1.3x) WITHOUT breaking foot
anchoring (feet stay on the floor) and WITHOUT changing the 32px collision.
Give the exact set_outfit/_measure anchor math with the scale factor.

## T6 Gold Scale instrument
Replace the primitive scale with the founder Gold Scale sprite; the moving
left/right indicator + large outlined numeric values. Minimal node approach.

End each with "GATE:" — the single assertion that fails on current code.
