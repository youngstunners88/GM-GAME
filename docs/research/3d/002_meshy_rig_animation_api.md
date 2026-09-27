# 002 — Meshy rigging + animation API (VERIFIED)

- `POST /openapi/v1/rigging {input_task_id | model_url, height_meters}` → rig task; humanoid,
  textured, <300k faces; source image-to-3D tasks are kept **3 days** — rig inside that window.
- `POST /openapi/v1/animations {rig_task_id, action_ids: [≤10], post_process: {operation_type:
  "change_fps", fps}}` → ONE GLB (`animation_glb_url`) with one clip per action, named from the
  library; 3 credits per action.
- `GET /openapi/v1/animations/library` → 678 presets (id, name, category). Useful for us:
  89 Combat Idle · 466 Regular Jump · 258 Crouch Look Around · 178 Hit Reaction · 403 Victory
  Fist Pump · 104 Side Shot · 170 Standing Reload · 237 Charged Axe Chop · 477 Rope Hang Idle ·
  224 Archery Shot · 231 Archery Aim · 183 Shot and Fall Backward · 464 Leap and Punch ·
  255 Angry Ground Stomp · 150 Hit Reaction with Bow.
- Rigged output keeps **base colour only** (normal/roughness maps are dropped). Clips import with
  `loop_mode = none` — set loops in code (`RunnerMotion.LOOPING`).
- Bones: standard humanoid names (Hips … RightHand, LeftHand, Head, head_end).

Docs: https://docs.meshy.ai/en/api/rigging · https://docs.meshy.ai/en/api/animation · https://docs.meshy.ai/en/api/animation-library
