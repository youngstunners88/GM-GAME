# Lil Blunt's personal armory

The session root owns `Ep2ArmoryState`. Rooms, HUDs and camera-held models project it. Background prebuilds use detached copies and bind the live state at activation. Attaching or replacing a camera never grants ammunition.

| ID | Player name | Separate ammunition | Game capacity |
|---|---|---|---|
| `winchester_1886` | Winchester 1886 | `rifle_round` | 4 |
| `remington_1875_gold` | Golden Remington 1875 | `revolver_round` | 6 |
| `bear_arrow` | Bear arrows | stored separately | 999 stored |

Ownership is earned. The hideout's actual Winchester handover binds its existing gun, including lesson loading and expenditure. Existing Stage 3 campaign progress migrates earned Remington ownership from old saves. The existing armed runner leg explicitly declares Remington possession; it grants a gun only once. A first acquisition supplies the existing Winchester allowance of 24 reserve rounds or 18 Remington reserve rounds. Re-entering an owned acquisition binds the same firearm and does not award another allowance. Completed Winchester training is saved; incomplete training retains loaded/reserve counts and cannot get stuck asking a full gun to load again. Standalone post-hideout preview scenes declare a Winchester entry fixture; production sessions bind their authoritative inventory instead.

Default controls: 1 / 2 select, Q previous, Tab inventory; LB / RB, Y and Back on a controller. The named buttons also accept finger taps. The panel offers keyboard rebinding, rejects conflicting gameplay/menu keys and retains controller bindings. Rebindings persist in `user://ep2_armory_controls.cfg`.

Both owned guns remain selectable when empty. Their loaded and reserve counts never mix. The 180 ms switch guard prevents same-frame fire; holstered cooldowns continue. Switching cancels an unfinished round's loading but retains completed round transactions. The Winchester's existing handling remains unchanged; the Remington uses the runner's existing 350 ms hammer cadence, six-round capacity and the shared single-round loading transaction. No automatic firearm switch or infinite FPS refill occurs. The existing runner auto-reload convention now spends finite reserve ammunition. Entering the runner cancels an unfinished FPS loader; a failed runner attempt restores its entry inventory, so repeated failures cannot permanently drain the restart supply.

The panel releases mouse capture and blocks player movement/fire while the world continues. The rifle lesson blocks switching until complete. Cameras, tutorial locks, three-heart health, title screen and access gates remain under their existing owners.

Bear corpses have stable `woods:<spawn-index>` IDs. Death records the bear's remaining finite quiver; expended arrows are not recreated. Corpses remain in the encounter and can be searched within 2.8 m, while facing the body and with unobstructed access, using E/interact or the Search button. Claiming is once-only; arrows above the storage cap remain on the body. Bodies remain after searching, and existing records reconstruct dead/searchable bodies when that encounter is built again. Arrow storage does not grant a bow or a third firearm slot.

The surface checkpoint snapshots both guns, selection, cooldown/loading state, stored arrows and corpse claims before danger. Retry restores that snapshot before respawning the same bear IDs. It cannot preserve a loot reward while also resurrecting its source. Bodies are disposed with the encounter or replaced by its checkpoint state.

Version 1 armory data is persisted through GameManager's existing save format. Wrong-shaped counts use SaveSafe and finite bounds. Changes are saved after a short debounce, at room handoff and application pause/close. This saves the armory; it does not add a complete world-position/story save system.
