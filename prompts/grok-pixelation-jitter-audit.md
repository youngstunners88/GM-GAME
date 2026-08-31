Role: PIXELATION / JITTER VISUAL AUDIT for a Godot 4.3 2D platformer
(GM-GAME / "Lil Blunt Adventure").

The founder attached two real screenshots this session (I, the orchestrating
Claude session, viewed them directly — you have not, this is an accurate
description, not a guess):

SCREENSHOT 1: Blaze Rush minigame HUD, top bar. "BLAZE DIAMONDS 0" and
"ATTEMPT 18" text render crisp. To the left of a red "TAP OUT (Q)" button
sits a small circular face icon, circled in blue by the founder — it is a
blurry, blocky, indistinct green blob with no readable facial detail at all.

SCREENSHOT 2: same minigame, lower band of the course. Three badge artworks
sit on a purple ground strip: a circular "THE ROOTS" badge (sharp), a
rectangular "DIAMOND LOUNGE" card (circled by founder — edges look soft,
warped, almost double-exposed compared to its neighbors), and a circular
gold/fire badge (sharp).

Founder verbatim: "The lil blunt icon is so pixelated i cant see whats going
on here... I dont want any of the artworks to ever be pixelated period!!!
This artwork is very jittery and difficult to see as a result!!!"

I already found one concrete fact: the TAP OUT face is a 585x586px source
PNG displayed at 58x58 (custom_minimum_size), a ~10x downscale — by far the
most extreme minification ratio of any UI sprite in this codebase — and its
.import file has mipmaps/generate=false, so its LINEAR_WITH_MIPMAPS filter
has no mip levels to actually sample. That is a solid pixelation root cause.
I have NOT yet root-caused the "jittery" complaint on the band art.

Your job: audit the band-art placement/scaling code below for what could
cause visible jitter/softness/warping specifically on ONE badge among
several that are otherwise sharp, given they all share the same scaling
code path. Things to check for: per-frame scale/position recalculation
that could round differently frame to frame, camera shake coupling
(ScreenShake calls) that displaces world-space art independent of the
player, sub-pixel position drift from a scrolling parallax/course-scroll
transform, or a stretch_mode/scale computation that behaves differently for
"is_wide" vs square art. Reference exact line numbers/constants. If the
provided code doesn't contain the actual cause, say precisely what class of
Godot behavior you'd check next (e.g. viewport stretch mode, MSAA/CanvasItem
setting) rather than inventing a file you can't see.

@include src/dashmode/blaze_rush.gd

Be concise and specific — this feeds directly into a fix that ships today.
