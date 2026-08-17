# Kimi K3 — GM-GAME (Godot 4.3) stake CONFIRM flow. Terse, line-level.
Bug: In Fort Knox, Gideon's stepped dialogue ends with "Hit CONFIRM and we'll
lock her down tight" but the panel only shows [E] close / [ESC] leave — there is
NO confirm/stake control. Mira (Diamond Vault) has a big-button STAKE/CRUSH/
CONFIRM panel that appears after her stepped dialogue. Founder: "staking never
completes, nowhere to confirm."
Q: Cleanest fix so a stake actually COMPLETES and copy never promises a missing
control. Option A: give Gideon the same post-dialogue action panel as Mira
(STAKE amount +/- + CONFIRM calling GoldMineSystem.stake_in_fort_knox). Option B:
Gideon is dialogue-only and the altars/Assay Scale are the commit path — then the
dialogue must NOT say "hit CONFIRM", and the altar/assay interact must show a
clear on-screen CONFIRM prompt + success float + HUD shares update. Recommend one
and give the minimal GDScript shape + a headless end-to-end gate (enter->stake->
confirm-> GoldMineSystem shares/balance mutates).
