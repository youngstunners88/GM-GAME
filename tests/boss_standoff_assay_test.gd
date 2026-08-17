extends SceneTree
## Founder directive PROMPT_CRITICAL_BOSSES_STAGE3_ASSAY_ALL_MODELS.md.
##
## THE MEASUREMENT THAT DROVE THESE FIXES (real web build, instrumented via
## level_base.gd's test-only chase telemetry, human-pattern Playwright drive,
## 16s per arena — full traces in docs/captures/2026-08-17-chase-numeric/):
##
##   Stage 2 Distributor   BEFORE          AFTER
##     boss path length    1564 px         3032 px   (~2x more visible motion)
##     gap min             0 px            137.8 px  (never touches the player)
##     gap mean            64.6 px         202.8 px
##     |dx|<60 samples     52% of fight    0%
##     level reloads       0               0
##
##   Stage 3 Claim Jumper  BEFORE          AFTER
##     level reloads/16s   4               2
##     longest survival    4.07 s          9-11 s
##
## Root cause: both bosses steered at the player's OWN x, so they locked on and
## rode on top of him. The camera follows the player, so a boss welded to the
## player's x has almost no motion RELATIVE TO THE SCREEN — it looks parked even
## while crossing thousands of world px. That is the founder's "the bosses don't
## move". It also made contact unavoidable, and boss contact restarts the level.
## Every prior fix RAISED pursuit aggression, tightening the lock-on and making
## the reported symptom worse — which is why ten attempts failed.
##
## These asserts fail on the pre-fix code.
##
## Run: godot --headless -s res://tests/boss_standoff_assay_test.gd

func _init() -> void:
	var fail := 0

	# --- Bosses hold a standoff instead of steering at the player's x -------
	var dist := FileAccess.get_file_as_string("res://src/boss/distributor.gd")
	if dist.contains("STANDOFF_X") and dist.contains("_standoff_side"):
		print("  [PASS] Distributor holds a horizontal standoff (no lock-on to player.x)")
	else:
		print("  [FAIL] Distributor still steers straight at the player's x"); fail += 1
	# The exact pre-fix line: target = player + (0, -HOVER_ABOVE) with no x offset.
	if dist.find("p.global_position + Vector2(0.0, -HOVER_ABOVE)") == -1:
		print("  [PASS] Distributor's old centre-lock target line is gone")
	else:
		print("  [FAIL] Distributor still targets dead-centre above the player"); fail += 1

	var cj := FileAccess.get_file_as_string("res://src/boss/claim_jumper.gd")
	if cj.contains("STANDOFF_X"):
		print("  [PASS] Claim Jumper has a standoff distance")
	else:
		print("  [FAIL] Claim Jumper has no standoff"); fail += 1
	# The hop used to commit to landing ON the player's x — the single line that
	# made Stage 3 unsurvivable. It must now aim at the standoff point.
	if cj.contains("aim_x") and cj.contains("STANDOFF_X"):
		print("  [PASS] Claim Jumper's hop lands at the standoff, not on the player")
	else:
		print("  [FAIL] Claim Jumper's hop still commits onto the player's x"); fail += 1
	# Pursuit must NOT have been weakened — the fix is about WHERE he aims, not
	# how fast he closes. Guard the speed floors so a future "make it gentler"
	# edit can't quietly turn the standoff into a retreat.
	if cj.contains("MIN_CHASE_SPEED") and dist.contains("MIN_PURSUE_SPEED: float = 345.0"):
		print("  [PASS] pursuit speeds are unchanged (standoff, not retreat)")
	else:
		print("  [FAIL] pursuit speed floors were weakened"); fail += 1

	# --- Assay panel: opaque background + value-dominant hierarchy ----------
	var vr := FileAccess.get_file_as_string("res://src/level/vault_realm.gd")
	var gs := vr.substr(vr.find("func _build_gold_scale"))
	gs = gs.substr(0, gs.find("\nfunc "))
	# Founder: "Remove this background". The panel must fully occlude the art.
	if gs.contains("Color(0.03, 0.04, 0.07, 1.0)") and gs.contains("Color(0.06, 0.045, 0.025, 1.0)"):
		print("  [PASS] Assay panel is fully OPAQUE (busy backdrop no longer shows through)")
	else:
		print("  [FAIL] Assay panel is still translucent — the art still shreds the type"); fail += 1
	if not gs.contains("_circle_points("):
		print("  [PASS] the halo ring behind the instrument is gone (muddied the needle)")
	else:
		print("  [FAIL] halo ring still present"); fail += 1
	# Hierarchy: the live VALUES must be the largest text on the panel.
	var sizes := {}
	for key in ["title", "staked_lbl", "staked_val", "return_lbl", "return_val", "hint"]:
		var i := gs.find("style_label(%s, " % key)
		if i != -1:
			sizes[key] = int(gs.substr(i).split(",")[1].split(")")[0].strip_edges())
	var vals: int = sizes.get("staked_val", 0)
	var biggest_other: int = maxi(maxi(sizes.get("title", 0), sizes.get("staked_lbl", 0)),
		maxi(sizes.get("return_lbl", 0), sizes.get("hint", 0)))
	if vals > biggest_other:
		print("  [PASS] live values are the largest text (%d vs %d) — clear hierarchy" % [vals, biggest_other])
	else:
		print("  [FAIL] values (%d) do not dominate other labels (%d)" % [vals, biggest_other]); fail += 1

	# --- Stage 3 declutter --------------------------------------------------
	var data: Resource = load("res://src/resources/level_03_data.tres")
	var counts := {}
	for c in data.get("collectible_spawns"):
		var t: String = c.get("type", "")
		counts[t] = counts.get(t, 0) + 1
	if counts.get("gold_token", 99) <= 6 and counts.get("wbtc", 99) <= 3 and counts.get("coin_btc", 99) <= 1:
		print("  [PASS] Stage 3 pickup confetti cut (tokens<=6, wBTC<=3, BTC<=1)")
	else:
		print("  [FAIL] Stage 3 pickups still spammed: %s" % str(counts)); fail += 1
	var carts: int = (data.get("mine_carts_fast") as Array).size() + (data.get("mine_carts_slow") as Array).size()
	if carts <= 2:
		print("  [PASS] mine carts thinned to %d (were 5 parallel toy systems)" % carts)
	else:
		print("  [FAIL] %d mine carts still running" % carts); fail += 1
	var l3 := FileAccess.get_file_as_string("res://src/level/level_03_gold_rush.gd")
	var dust := l3.substr(l3.find("func _setup_ambient_dust"))
	dust = dust.substr(0, dust.find("\nfunc "))
	if dust.count("Vector2(") <= 3:
		print("  [PASS] gold-dust emitters cut to 1 (were 6 — stage-wide sparkle noise)")
	else:
		print("  [FAIL] gold-dust emitters still blanket the stage"); fail += 1

	print("BOSS_STANDOFF_ASSAY: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
