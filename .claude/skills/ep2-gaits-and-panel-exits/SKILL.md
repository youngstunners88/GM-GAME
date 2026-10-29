---
name: ep2-gaits-and-panel-exits
description: Improve Sheriff/Utah skeletal walking without replacing founder appearances; provide consistent visible × exits on gameplay tabs while preserving fullscreen and modal ownership.
---

# Visible motion and safe panel dismissal

Read ep2-founder-regression-repair first. For rigs use gm-blender-godot, ep2-rest-aware-retargeting and ep2-tripo-folk-to-game. Verify actual Blender availability; record fallback versions and never claim unavailable tooling ran.

- Inspect source skins and animations. Sheriff previous_sheriff/sheriff.glb is historically static; preserving it does not justify statue bobbing. Add a weighted rig to a separate recoverable asset, retain the founder face/outfit/textures, and compare neutral and moving silhouettes.
- Utah has a Mixamo rig. Diagnose complete loop/rest transforms, foot height, loop seam, stride speed and clip switches; do not add more whole-body bob. Maintain distinct carry/stair upper-body performance with grounded lower limbs.
- Author a complete alternating stance/swing gait. Measure final-scale foot clearance/penetration, stance sliding and bone-length preservation over at least two cycles at gameplay speeds. Inspect front and side moving poses in Godot Compatibility.
- Use a reusable top-left × close button, minimum 44 canvas units, no keyboard focus capture. Wire each panel to its own existing close path; controls keep pointer interaction available during paused trading. Preserve Escape and P/M/Tab conventions.
- Audit trade, region map, inventory/weapon selector, pause/help and Episode 1 dismissible panels. Mandatory quizzes/rewards/access gates must not gain bypasses.
- A mouse/touch close must not invoke ui_cancel or document.exitFullscreen. Test in an actual fullscreen browser with click close, Escape and return-to-play; record desktop/touch evidence separately.
