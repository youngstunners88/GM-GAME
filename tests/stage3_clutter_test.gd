extends SceneTree
## Stage 3 clutter + hammer regression gate (founder directive
## PROMPT_STAGE3_AESTHETICS_HAMMER_CLUTTER.md, 2026-08-16).
##
## Each assert is written so the PRE-FIX state fails it:
##   A. Useless/random blocks — the 5 melt forges used to FLOAT at y=450-500
##      (body bottom ~495-545, ~105-155px above the y=650 ground) so the player
##      could never stand in them to press E. Now thinned to <=3, each grounded
##      (pos.y >= 590 => base sits on the floor). And the bare brown ColorRect
##      "knox_bridge" box (a red-circled "trashy block") is gone from the script,
##      replaced by a real ground_segment covering the 2620-2760 door-footing pit.
##   B. Hammer / big_axe — the thrown big axe reads substantial (BIG_SCALE >= 1.9,
##      ~78px vs the base throw's ~9px) and the pickup is enlarged (>= 1.4) and
##      still uses its OWN art (sprite_item_bigaxe.png), distinct from the pickaxe.
##
## Run: godot --headless -s res://tests/stage3_clutter_test.gd

func _init() -> void:
	var fail := 0

	# --- A. Melt forges thinned + grounded ---------------------------------
	var data: Resource = load("res://src/resources/level_03_data.tres")
	var forges: Array = data.get("melt_forges")
	if forges.size() <= 3:
		print("  [PASS] melt forges thinned to %d (was 5 identical stations)" % forges.size())
	else:
		print("  [FAIL] too many melt forges: %d (spam clutter)" % forges.size()); fail += 1
	var floating := []
	for f in forges:
		var p: Vector2 = f.get("pos", Vector2.ZERO)
		# body bottom = pos.y + 45; grounded means it reaches the y=650 floor.
		if p.y < 590.0:
			floating.append(p)
	if floating.is_empty():
		print("  [PASS] no melt forge floats above the ground (all grounded, pos.y>=590)")
	else:
		print("  [FAIL] %d melt forge(s) still float unreachable: %s" % [floating.size(), str(floating)]); fail += 1

	# --- A. Knox pit filled by a real ground segment, script box gone -------
	var segs: Array = data.get("ground_segments")
	var pit_filled := false
	for s: Vector4 in segs:
		if s.x <= 2620.0 and (s.x + s.z) >= 2760.0:
			pit_filled = true
	if pit_filled:
		print("  [PASS] Fort Knox door-footing pit (2620-2760) is a real ground_segment")
	else:
		print("  [FAIL] the 2620-2760 pit is not covered by a ground_segment"); fail += 1
	var src := FileAccess.get_file_as_string("res://src/level/level_03_gold_rush.gd")
	if src.find("knox_bridge") == -1 and src.find("kbdeck") == -1:
		print("  [PASS] the bare script-built brown ColorRect bridge box is gone")
	else:
		print("  [FAIL] level_03 still hand-builds the knox_bridge ColorRect box"); fail += 1

	# --- B. Big axe throw substantial + distinct pickup --------------------
	var axe_src := FileAccess.get_file_as_string("res://src/combat/axe.gd")
	var big_scale := 0.0
	for line in axe_src.split("\n"):
		if line.strip_edges().begins_with("const BIG_SCALE"):
			big_scale = float(line.split(":=")[1])
	if big_scale >= 1.9:
		print("  [PASS] thrown big axe reads substantial (BIG_SCALE=%.2f)" % big_scale)
	else:
		print("  [FAIL] thrown big axe still small (BIG_SCALE=%.2f)" % big_scale); fail += 1

	var pickup := FileAccess.get_file_as_string("res://src/powerups/big_axe.tscn")
	if pickup.find("sprite_item_bigaxe.png") != -1 and pickup.find("sprite_item_pickaxe.png") == -1:
		print("  [PASS] big axe pickup uses its OWN art, distinct from the pickaxe")
	else:
		print("  [FAIL] big axe pickup shares the pickaxe art"); fail += 1
	var pscale := 0.0
	var lines := pickup.split("\n")
	for i in range(lines.size()):
		if lines[i].begins_with("scale = Vector2("):
			pscale = float(lines[i].replace("scale = Vector2(", "").split(",")[0])
	if pscale >= 1.4:
		print("  [PASS] big axe pickup enlarged for presence (scale=%.2f)" % pscale)
	else:
		print("  [FAIL] big axe pickup too small (scale=%.2f)" % pscale); fail += 1

	print("STAGE3_CLUTTER: %s" % ("ALL PASS" if fail == 0 else "%d FAILURE(S)" % fail))
	quit(fail)
