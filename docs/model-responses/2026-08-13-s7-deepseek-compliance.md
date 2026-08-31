<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: prompts/s7-deepseek-compliance.md
     files inlined: 1
     tokens: 1233 in / 3568 out
     cost: $0.0098
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
| S7 area | Verdict | Compliance / regression risk |
|---|---|---|
| Vault UI text size + outline | PASS | Use `add_theme_font_size_override`, `font_outline_color`, `outline_size` only. Any new copy must stay neutral and contain no wallet/contract addresses. |
| Large Diamond Vault buttons: show holdings / stake / crush / confirm | PASS | Keep labels positive and mechanical: “SHOW HOLDINGS”, “STAKE”, “CRUSH”, “CONFIRM”. Avoid “withdraw”, “cash out”, “wallet address”, or payout wording. |
| Stage 2 bomb + shards cross whole arena | PASS | Physics/tuning only. Ensure projectiles despawn/expire; no threads added. No save/load impact. |
| Boss horizontal chase in real Stage 2 arena | PASS | Tuning only. Keep chase bounds explicit from level; no addresses/content risk. |
| Player visual slightly bigger | RISK | Compliance pass, but visual scale is regression-prone: collision must stay unchanged, and foot anchor must account for scaled texture height. Do not scale Player root if skateboard/child nodes should not grow. If render scale gets serialized, save/load becomes affected. |
| Oversized on-screen element shrink/reposition | PASS | No content/address risk. If UI, keep safe-area/layout safe. |
| Stake scale using founder Gold Scale / BTC art | PASS only if wired to existing stable path | Use `preload("res://...")` or exported `NodePath` to actual founder art. Do not invent a new clerk/scale. BTC/gold symbolism is content-positive, provided no wallet address is shown. |
| Godot 4.3 Variant parse trap in new UI code | RISK | All new UI code must avoid `:= <Variant>` from `get_node`, `get_first_node_in_group`, scene instantiation. Use explicit types: `var label: Label = $...`, `var btn: Button = ...`. |
| Non-threaded web export | PASS | Planned work is main-thread only. Projectile tuning may increase node count; watch projectile lifetime/despawn. |
| Save/load unaffected | PASS | UI-only + projectile tuning + render scale do not change save data, unless render scale is added as serialized state. If so, version/ migrate. |

**Most useful regression test:**  
Load the Player scene headlessly, set the new player visual render scale to something non-1.0 such as `1.3`, advance one frame, and assert the sprite’s visual bottom still matches the player feet local anchor within 1px:

`abs(_spr.to_global(Vector2(0, tex_h / 2.0)).y - player.to_global(Vector2(0, FEET_LOCAL_Y)).y) <= 1.0`

Also assert the collision shape local extents are unchanged. This catches the likely foot-anchor/skateboard offset mistake immediately after visual scaling.