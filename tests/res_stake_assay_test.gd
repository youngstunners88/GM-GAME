extends Node2D
## Founder live residuals, each written to FAIL on the pre-fix code:
##   #1 Stake CONFIRM: Gideon promised "hit CONFIRM" but the panel had no commit
##      control. Now the terminal E actually stakes 25% of GOLD into Fort Knox —
##      GoldMineSystem.fort_knox_shares increases and gold_balance drops.
##   #2 Assay Scale design: the title / STAKED / RETURN / hint labels used to
##      overlap. Now no two Assay Scale labels' rects intersect, and the scale
##      art is larger (>= 200px).
##
## Run: godot --headless res://tests/res_stake_assay_test.tscn

const FORT_KNOX := preload("res://src/level/fort_knox_realm.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("LIVE RESIDUALS — STAKE CONFIRM + ASSAY DESIGN:")
	await _test_gideon_confirm_stakes()
	await _test_assay_labels_no_overlap()
	print("RES_STAKE_ASSAY: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _find(n: Node, pred: Callable, acc: Array) -> void:
	if pred.call(n):
		acc.append(n)
	for c in n.get_children():
		_find(c, pred, acc)

## #1 — Gideon's dialogue ends in a REAL confirm that mutates GoldMineSystem.
func _test_gideon_confirm_stakes() -> void:
	GoldMineSystem.reset_session()
	GoldMineSystem.gold_balance = 400
	var realm: Node = FORT_KNOX.instantiate()
	add_child(realm)
	await get_tree().process_frame
	var shares_before: int = GoldMineSystem.fort_knox_shares
	var gold_before: int = GoldMineSystem.gold_balance
	realm.call("gideon_open")
	await get_tree().process_frame
	# Step through every line; the terminal E must CONFIRM the stake (not dead input).
	for _i in range(8):
		realm.call("gideon_step")
	_check("Gideon's CONFIRM actually stakes GOLD into Fort Knox (shares up, gold down)",
		GoldMineSystem.fort_knox_shares > shares_before and GoldMineSystem.gold_balance < gold_before,
		"shares %d->%d, gold %d->%d" % [shares_before, GoldMineSystem.fort_knox_shares, gold_before, GoldMineSystem.gold_balance])
	# Copy honesty: the final dialogue line must not promise a control that isn't wired.
	var dlg = realm.call("_make_gideon_dialogue")
	var last: String = dlg.lines[dlg.lines.size() - 1]
	_check("Gideon's last line promises CONFIRM and CONFIRM is real",
		last.to_upper().find("CONFIRM") != -1)
	realm.queue_free()
	GoldMineSystem.reset_session()
	await get_tree().process_frame

## #2 — no two Assay Scale labels overlap; the scale art is larger.
func _test_assay_labels_no_overlap() -> void:
	var realm: Node = FORT_KNOX.instantiate()
	add_child(realm)
	await get_tree().process_frame
	var scales: Array = get_tree().get_nodes_in_group("assay_scale")
	_check("Fort Knox has the Assay Scale", scales.size() >= 1)
	if scales.is_empty():
		realm.queue_free(); return
	var scale: Node = scales[0]
	# Collect its Label children and compute real rects (position + minimum size,
	# which Godot fills from the theme font once in-tree).
	var labels: Array = []
	_find(scale, func(n: Node) -> bool: return n is Label, labels)
	_check("Assay Scale has its instrument labels", labels.size() >= 3, "%d labels" % labels.size())
	# Larger scale art.
	var sprs: Array = []
	_find(scale, func(n: Node) -> bool: return n is Sprite2D, sprs)
	var scale_h := 0.0
	for s in sprs:
		if s.texture != null and s.texture.resource_path.findn("gold_scale") != -1:
			scale_h = s.texture.get_height() * s.scale.y
	_check("Assay Scale art is larger (>= 200px)", scale_h >= 200.0, "scale height %.0f" % scale_h)
	# No two label rects intersect.
	var rects: Array = []
	for l in labels:
		var sz: Vector2 = (l as Label).get_minimum_size()
		sz.x = maxf(sz.x, 40.0); sz.y = maxf(sz.y, 24.0)
		rects.append({"r": Rect2((l as Label).position, sz), "t": (l as Label).text})
	var overlap := ""
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if (rects[i].r as Rect2).intersects(rects[j].r as Rect2):
				overlap = "'%s' overlaps '%s'" % [rects[i].t, rects[j].t]
	_check("no two Assay Scale labels overlap (text no longer masks itself)",
		overlap == "", overlap)
	realm.queue_free()
	await get_tree().process_frame
