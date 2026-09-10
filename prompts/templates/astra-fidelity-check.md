# Art-direction fidelity check — Episode 2 (Gold Mine)

You are reviewing a REAL SCREENSHOT of the running game against the founder's
own reference art. Both are attached as images.

**Image order:** the FIRST image is the live game capture. The remaining images
are the founder reference art — the only approved source of art direction for
this episode.

## Context you need

- Godot 4.3, 3D. The **web build runs Godot's Compatibility (GL) backend**, so
  volumetric fog, SSR, SSAO and SDFGI are unavailable, and a metallic surface
  with no reflection probe renders near-black. Do not recommend those.
- Geometry is deliberately simple (boxes, capsules, a small number of
  headless-built GLB props). Do not grade the model complexity — grade
  **colour, value, lighting, composition, silhouette and readability**.
- This is a **runner**: the camera moves at 12 m/s down a tunnel. Hazards must
  be readable in well under a second.
- The overlay text at the top-left is a debug HUD. Ignore it.

## Answer these, in this order, and nothing else

### 1. Verdict
One line: does the capture read as the same world as the references? Pick one —
**ON MODEL / DRIFTING / OFF MODEL** — and say why in one sentence.

### 2. What matches
The specific things the capture gets right. Be concrete.

### 3. What drifts — ranked
Ranked most damaging first. For each: what is wrong, what the reference shows
instead, and the **smallest change** that would close the gap. Prefer changes
to material values, light values, and placement over new geometry. If new
geometry really is the only fix, say so explicitly and say what shape.

### 4. Readability at speed
Which objects in this frame would a player fail to read in time, and why.

### 5. What you cannot judge from this frame
Be explicit about it rather than guessing.

## Rules
- Do not describe the images back to me. Give findings.
- Do not invent art direction that is not in the references. If the capture
  needs something the references do not cover, say "not covered by the
  references — founder question" and move on.
- No vague praise. Every note must be actionable.
