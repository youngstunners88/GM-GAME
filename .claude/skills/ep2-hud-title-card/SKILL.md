---
name: ep2-hud-title-card
description: Episode 2 HUD is clean - no episode banner, no beat/inventory line, no always-on key strip. The Smelting Facility shows a "THE SMELTING FACILITY" title card that fades; K shows the controls for 3 seconds. TRIGGER on any edit to ep2_entry.gd HUD, "the HUD is in the way", or new chamber text.
---
# Rules
- `Ep2Entry._refresh_hud` never prints "EPISODE 2" and prints nothing in the facility; `_hint` is cleared unless `_keys_t > 0` (K, `KEYS_SHOW_SECONDS` = 3).
- Title card: `_update_title_card()` fires once per chamber instance when the beat leaves CINEMATIC; fade in 0.6 s, hold 1.8 s, fade out 1.2 s.
- K changes no binding. Key map stays the one in `ep2-free-roam-controls`.
