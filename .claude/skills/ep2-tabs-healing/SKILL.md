---
name: ep2-tabs-healing
description: Make Dude's stored Chill Bud a selectable, usable Tabs item that restores Lil Blunt to all three hearts, with correct pause/input ownership, count and save behavior.
---

# One bud restores three hearts

Use ep2-world-presence-and-consumables and the existing mobile/touch and pause contracts.

- Store/count buds only through GameManager's existing acquisition/inventory/save paths. Keep Dude's one-time free gift and paid packs; opening or closing Tabs never grants items.
- Add a visible selectable bud item and explicit Use action to Tabs. Route keyboard, pointer, controller and raw multi-finger input through one deduplicated transaction. A drawn `H` hint alone is not an actionable item; no key names on touch UI.
- One successful use restores the owning damageable room's actual health to its existing cap of3 and consumes exactly one bud. Do not add a second health system, revive a failed/dead run or heal the horse. Full health, no buds or unsupported contexts leave count and health unchanged and explain the state.
- Keep the panel's pause owner, fullscreen-safe ×, weapon preview/reload state and gameplay input intact. Healing inside the paused panel must refresh its hearts/count immediately and save through existing paths.
- Test from Dude acquisition through the real open Tabs input path at1/2/3 hearts, zero stock, repeated events, close and reopen, checkpoint/load and mobile/controller alternatives. Update old one-heart assumptions explicitly; retain the three-heart cap.

## Verified repair lesson

Godot Input.parse_input_event expects window coordinates. Native GUI fixtures with canvas coordinates must use viewport.push_input(event,true), allow layout frames and send mouse motion before click. Do not change production because a malformed coordinate fixture misses a button. Keep per-button same-frame activation guards and refresh selection/use immediately.
