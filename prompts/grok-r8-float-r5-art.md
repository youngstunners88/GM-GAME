# Grok 4.5 — TWO deliverables for Episode 1 boss + Blaze Rush art

## A. The Distributor (Level 2 crystal boss) — float redesign feel

Current state: 96x96 sprite, walks on the ground with gravity
(`velocity.y += 980*delta; move_and_slide()`), patrols left/right and flips
at walls. Problems: (1) it can walk off a pit and fall out of the arena
forever, soft-locking the fight; (2) it reads as a small ground grunt, not a
final boss. Theme: Crystal Caverns / the DIAMONDS protocol (levitating
diamonds, ETH-orb projectiles, a gravity "hoard pull" attack).

Give a SHORT feel spec (concrete numbers) for turning him into a LARGER,
LEVITATING boss that floats on a diamond disc and never touches the floor:
1. Scale multiplier vs the current 96px (how big reads as "final boss" but
   still fits a ~720px-tall arena with room to dodge).
2. Hover motion: a resting hover-Y band + a gentle bob (amplitude px, period
   s) + how he drifts horizontally toward/around the player WITHOUT gravity,
   so he never falls and never feels like a static balloon. Give the drift
   speed and how he should reposition between attacks.
3. One line on how the levitating-diamond disc under him should move with him.
Keep it implementable in a Godot _physics_process that clamps to arena
bounds. No code — numbers + intent.

## B. Blaze Rush (Geometry Dash-style auto-runner) — visual beat sheet

It's currently a near-bland void with basic shapes. It runs left→right at
speed, tap to jump, hazards below. Protocol branding available: SmokeRing
(green weed mascot on a rocket, "FOMO"), DIAMONDS (teal gem), GoldMine
(gold pickaxe crest). Give a beat sheet for a readable, branded reskin:
- Background layer intent (depth without hurting hazard readability).
- Platform vs hazard vs collectible colour language (contrast rules).
- Where the 3 protocol logos appear as LANDMARKS (not clutter).
- One "wow" moment. Gameplay readability first. No GD copyrighted assets.
Short, concrete, no code.
