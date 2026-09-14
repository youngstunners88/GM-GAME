# Episode 2 (Gold Mine) — art-direction extraction from founder references

You are the art-direction reviewer for a Godot 4.3 **3D** game, Episode 2 of
"Lil Blunt Adventure". The hero is Lil Blunt, a friendly cannabis-bud miner
character. Episode 2 is a minecart runner through a gold mine, plus an
on-foot chamber encounter.

**The three images attached are the founder's own reference art. They are the
only source of truth for the look.** I must not invent art direction, so your
job is to READ these images and give me numbers I can put straight into
Godot `StandardMaterial3D` settings.

Right now the game is a graybox: untextured box meshes with flat albedo
colours. The next commit re-textures those boxes. Nothing changes about
geometry or gameplay — materials only.

## What I need from you, in this order

### 1. Palette table
For each of these surfaces, give **hex albedo**, **metallic (0-1)**,
**roughness (0-1)**, and where relevant an **emission colour + strength**:

- cave rock wall (the dark surrounding stone)
- gold vein / glitter embedded in the rock
- weathered wood (mine cart body, support beams, rail ties)
- brass / bronze banding and fittings (cart bands, rivets, helmet)
- iron rail track
- lantern glow
- granite boulder (the grey rolling hazard)
- loose gold nugget / gold pile
- steel zipline cable
- the "danger" reads: what colour is an arrow/projectile hazard in this world

### 2. Value structure
How dark is the rock relative to the gold? Give me an approximate value ratio.
The last build was blown-out white and unreadable — I need to know how far
down the ambient and albedo should sit for gold to read as the bright thing.

### 3. Readability at speed
This is a runner. Hazards must be distinguishable in under a second at speed.
Given this palette, which hazard/background pairs are at risk of blending, and
what is the cheapest fix that stays on-model (rim light? emissive edge?
silhouette change?).

### 4. Lighting recipe
Godot `WorldEnvironment` + `DirectionalLight3D` + point lights. Give me:
ambient light colour and energy, directional light colour/energy/angle, fog
settings if the references imply atmosphere, and where warm point lights
(lanterns) should sit. The references clearly have strong warm bloom — give me
glow settings that get close without washing out.

### 5. What the references do NOT cover
List anything I will need for a mine runner that these three images give me no
guidance on. I will take those back to the founder as open questions rather
than guessing.

## Format
Terse. Tables where possible. Real numbers, not adjectives. Do not describe the
images back to me — I have seen them. Give me settings.
