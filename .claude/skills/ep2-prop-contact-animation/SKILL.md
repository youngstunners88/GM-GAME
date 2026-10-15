---
name: ep2-prop-contact-animation
description: Author and measure independent palm/prop grips and physical interactions for Inferno's rifle, bears' bows/magazines, quad grips, lever, leaves and handover. Use for floating guns, wrong grips, stiff hands, impossible reaches or props moving without contact.
---

# Contact owns the action

Read design/ep2/motion/CHARACTER_MOTION_CONTRACT.md. Use separate rigid props with authored contact markers and phases; a BoneAttachment3D parent is necessary but not proof of a grip.

## Independent markers

Define palm/knuckle and support points on the actual character geometry, plus stock grip/trigger/fore-end/muzzle and support points on the prop. Store local frames, surface normals and physical dimensions after normalization.
Measure character markers against independent prop markers and nearest relevant mesh surfaces after animation and all SkeletonModifier3D passes. A marker computed from the same hand midpoint as the prop is a tautology; a wrist alone is not the palm.
Use metre-aware holders once: preserve Ep2Actor's inverse rig scale, positive determinant, semantic front and final drawn bone pose. Sample on the correct final-pose callback. The old skeleton_updated/BoneAttachment timing assumptions must be tested at 30/60 Hz and during blending.

## Inferno's Winchester

- Treat carry, low ready, aim/fire, lever cycle and trade handover as distinct poses. Preserve the founder rifle and his actual left/right anatomical mapping; do not select a hand from camera screen side.
- During a two-hand action, one primary grip drives the rifle and the other hand solves to the fore-end within reach. Wrist/palm orientation and stock/shoulder/cheek clearance are part of the contact, not just position.
- Recoil pivots around a declared grip/contact frame with matching body/forearm motion and recovery. Do not move the rifle independently 0.2 m along the shot direction as woods_quad._bull_fire_at currently does. Keep the muzzle event on the actual barrel.
- The Bull's fused right fist/pouch must be skin/topology-tested before a support-hand pose. Don't claim finger gripping from a rig without finger joints. A valid one-handed vertical carry may remain as a separate rest pose; it is not a substitute for firing posture.
- Trade rifle and Bull's own rifle have distinct ownership: attach/transfer only at real contact, hide/release only the transferred item. Preserve tutorial/acquisition timing.
- Hideout and interlude handling currently use different placement paths. Audit both; repairing one screenshot does not repair the other.

## Bears and world interactions

- Bow: grip the stave at an authored palm frame; the other paw meets the string/nock during draw and leaves it at release. Model actual string tension and an arrow aligned to the nock; arrow emission must agree with the pose event. A static string plus a free paw is a fail.
- Magazine: both paw contacts meet its edges/spine at plausible width/orientation. Turning a page needs a released/repositioned paw while the other supports the book; merely tipping a book at the midpoint of widely separated hands does not prove reading.
- Quad: rider seat/feet are supported, both hands match real grip landmarks, no elongated elbows. Preserve mount/dismount transitions and free the correct hand before using another prop.
- Lever/leaves: approach, contact, apply force, release, settle. The hand must touch before a handle or leaf cluster moves. Fixed furniture stays in world space; only a picked object attaches to a hand.
- Sleeping/death: bodies rest on terrain and stop attacking. Wake/rise/reach transitions need continuous support; do not squash the whole model to fake motion.

Use restrained solve ranges and joint limits. If a target is out of reach, move the body/prop through plausible choreography or reject the action. Never lengthen bones, enlarge props to conceal missed contact, or silently clip through body/world geometry.
Validate with ep2-character-motion-qa over complete motion/transition intervals, including interruption and retry. The contract's tolerances are proposed acceptance targets, not claimed measurements.
