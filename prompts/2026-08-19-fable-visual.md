# Lil Blunt Adventure — visual/UX defect audit (Godot 4.3, 16-bit pixel-art platformer)

You are the visual quality / UX auditor. The founder (non-technical, furious, has asked
for some of these repeatedly) reports the following. Fix the SOURCE composition, never
paint over a defect and never crop to conceal it.

## FIX-07 / FIX-08 — Fort Knox "Assay Scale" panel
Founder: "Raise the 'FORT KNOX ASSAY - WEIGH IT. STAKE IT. 100-DAY MINERS ONLY' TEXT.
Why would I have to tell you this!! Are you so stupid that you cant understand that NO
TEXT SHOULD MASK OTHER TEXT!!!"
and: "Remove the vertical rectangle shading box. Just keep the circular shade by the
scale as it will suffice in creating the necessary colour contrast."

What the screenshot actually shows: a right-hand panel titled "ASSAY SCALE" containing a
scale illustration on a dark CIRCULAR shade, sitting on a tall dark VERTICAL RECTANGLE
panel; and, in the middle of the hall, the three-line block "FORT KNOX ASSAY / WEIGH IT.
STAKE IT. / 100-DAY MINERS ONLY" drawn ON TOP OF (colliding with) two other labels:
"2888-DAY POOL — PRIMARY (2x)" and "FORT KNOX SECURITY SENTINEL".
A previous session already tried moving that sign from x=1960 to x=1780 and wrapping it
to 3 lines. That did NOT fix it — it collided with different text instead. Treat that
attempt as failed and design a real layout.

Founder's own suggested hierarchy:
    ASSAY SCALE / [visual] / STAKED / RETURN / [values]
    FORT KNOX ASSAY / WEIGH IT. / STAKE IT. / 100-DAY MINERS ONLY

## FIX-12 — Blaze Rush "rectangle residue"
Founder: "these rectangle residue blocks need to be removed so that the background can
be clean. You'll notice that they PERSIST THROUGHOUT THE STAGE."
Screenshot shows: dark navy horizontal BARS floating in the sky, and a huge flat
PURPLE/VIOLET rectangle filling the entire lower half of the screen below the forest
horizon. (The neon-green cube is the Geometry-Dash-style player avatar and is
INTENTIONAL — do not remove it.)

## FIX-01 — wasted screen space
The itch.io page shows the game canvas small in the top-left with a large empty white
page area around it.

## Your task
For each defect: name the exact node/构造 in the source that causes it (file:line),
say WHY it reads as cheap/broken, and give a concrete fix with real coordinates/sizes.
For the Assay panel, produce a full layout with explicit positions and font sizes that
provably cannot overlap at a 1280x720 viewport, and show the arithmetic.
Rank everything by how much it damages perceived production quality.

## Source
@include src/level/vault_realm.gd
@include src/dashmode/blaze_rush.gd
