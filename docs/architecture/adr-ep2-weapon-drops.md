# ADR: Episode 2 weapon drops (what a dead gunman leaves)

Date: 2026-11-07. Status: accepted (founder brief 2026-11-07, item 1). Not founder-verified.

## Context
When Lil Blunt killed a trail bandit his gun was hidden (`lake_trail.gd` `_drop_bandit`): it vanished. The bodies fell 8-11 m off the
trail, but the rider's lane was clamped to +-2.2 m, so nothing beside the trail could be reached. The founder wants the gun the enemy held
and its matching ammo to drop where he fell, stay until taken, and go into the one armory.

## Decision
- One shared node, `Ep2WeaponDrop` (`src/episode2/chamber/ep2_weapon_drop.gd`): the man's own held gun node is moved into it and laid on
  its side with a box of rounds by his hand. `place()` when a man dies, `nearest()` for the prompt, `take()` on ride-over (0.9 m) or the
  interact control (2.4 m reach). The prompt uses the HUD search prompt: keys shown -> text with the bound key; touch -> the INTERACT
  button lights. No timer removes a drop.
- The record lives in `Ep2ArmoryState.corpses` (`record_drop` / `claim_drop`), beside the searched bear bodies, so it is saved,
  taken once, and survives a retry. No second inventory: a new gun goes through `acquire` (loaded) with only the dead man's rounds as its
  reserve; an owned gun still gives its rounds; reserves cap at `RESERVE_CAP` (the store's cap) and what does not fit stays on the ground.
- Trail bandits carry the Borchardt C93: the code's own rule says they carry the same gun as the town-draw stranger, who has held a
  Borchardt since b58da5cd (2026-11-02). Ammo is the Borchardt's own (`seven_six_five`), 8 rounds per man.
- The lane widens toward an untaken drop within 7 m of trail so he can ride to it, and eases back once it is taken.
- A man who dies on a raft goes into the river with his gun: no drop (common-sense rule). The town stranger keeps his scripted Beat.LOOT.

## Consequences
- Gate `tests/ep2_weapon_drops_test.tscn` (in CI). Render `tools/ep2_shots/weapon_drop_shot.tscn`.
- The ride to a drop beside a rock has no collision with the rock (the trail never had any).
- Raft men carry no modelled gun (glint only). Other armed rooms add drops by calling `Ep2WeaponDrop.place`.
