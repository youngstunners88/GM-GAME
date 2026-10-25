extends Node
## EP2 PBR + CAD GATLING (founder 2026-10-25: "hyperreal ... not grey primitives", "Colt Gatling - full quality pass").
##  * Ep2Pbr dresses an authored material with its photo-scanned set (albedo grain, normal, ORM) and KEEPS the authored mean colour.
##  * The CAD Gatling (tools/ep2_cad/gatling_cad.py -> tools/ep2_blender/build_gatling_cad.py) keeps the node tree and markers the game
##    drives (Ep2GatlingPost), comes in dressed, and the gunner's line of sight from Gat_Eye to the muzzle clears the drum.
## Run: godot --headless res://tests/ep2_pbr_test.tscn

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _ready() -> void:
	print("EP2 PBR:")
	check("the PBR sets are on disk (streamed extras)", Ep2Pbr.available())
	var brass := Color(0.72, 0.55, 0.25)
	var m: StandardMaterial3D = Ep2Pbr.make("brass_worn", brass, 0.45, 0.58)
	check("a dressed material has albedo, normal and ORM maps", m != null and m.albedo_texture != null and m.normal_enabled
		and m.normal_texture != null and m.roughness_texture != null and m.ao_texture != null and m.metallic_texture != null)
	if m != null:
		check("...reads roughness / AO / metal from the ORM's G / R / B channels",
			m.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN and m.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
			and m.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
		check("...object-space triplanar (sticks to moving parts), mipmapped filtering",
			m.uv1_triplanar and not m.uv1_world_triplanar and m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
		var mean: Color = Ep2Pbr.MEAN["brass_worn"]
		var got: Color = m.albedo_color.srgb_to_linear()
		var want: Color = brass.srgb_to_linear()
		check("...keeps the authored colour on average (tint x set mean = authored, linear)",
			absf(got.r * mean.r - want.r) < 0.01 and absf(got.g * mean.g - want.g) < 0.01 and absf(got.b * mean.b - want.b) < 0.01,
			"%s x %s vs %s" % [got, mean, want])
		check("...metal is capped for the Compatibility renderer (no black holes indoors)", m.metallic <= 0.65 and m.metallic > 0.3)
	check("the same request is cached (one material per look)", Ep2Pbr.make("brass_worn", brass, 0.45, 0.58) == m)
	check("an unknown name is left alone", Ep2Pbr.set_for("LampGlow") == "" and Ep2Pbr.set_for("Brass.001") == "brass_worn")

	print("-- the CAD Gatling")
	var post := Ep2GatlingPost.new()
	add_child(post)
	var ok: bool = post.build(Ep2Extras.GATLING, 0.0)
	check("the CAD gatling_post.glb builds the Gatling the game drives", ok)
	if ok:
		for n in ["Gat_Yaw", "Gat_Pitch", "Gat_Barrels", "Gat_Crank", "Gat_Muzzle", "Gat_Eye", "Gat_Eject", "Gat_Sign"]:
			check("...has %s" % n, post.model.find_child(n, true, false) != null)
		var pitch: Node3D = post.model.find_child("Gat_Pitch", true, false)
		var muzzle: Node3D = post.model.find_child("Gat_Muzzle", true, false)
		var eye: Node3D = post.model.find_child("Gat_Eye", true, false)
		check("...the muzzle marker is where the bore ends (pitch-local x 1.52)", muzzle.position.distance_to(Vector3(1.52, 0.0, 0.0)) < 0.01, str(muzzle.position))
		var dressed: int = 0
		var flat: Array = []
		for mi in post.model.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_override != null:
				continue                      # runtime effects (the muzzle flash) carry their own material
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var mat: Material = (mi as MeshInstance3D).get_surface_override_material(si)
				var authored: Material = (mi as MeshInstance3D).mesh.surface_get_material(si)
				if mat != null and String(mat.resource_name).begins_with("Pbr_"):
					dressed += 1
				elif authored == null:
					flat.append("%s#%d (no material)" % [mi.name, si])
				else:
					flat.append("%s#%d %s" % [mi.name, si, String(authored.resource_name)])
		check("...it comes in dressed: bronze, blued steel, iron, walnut, stone, burlap, rope, planks", dressed >= 18 and flat.is_empty(),
			"dressed %d, still flat %s" % [dressed, str(flat)])
		# the drum and jacket are period gun bronze, not the kit's pale shared Brass (cream in desert sun, founder "readable, period")
		var bronze_seen: int = 0
		var bronze_bad: Array = []
		var bmean: Color = Ep2Pbr.MEAN["brass_worn"]
		var want_b: Color = Ep2GatlingPost.BRONZE.srgb_to_linear()
		for mi in post.model.find_children("*", "MeshInstance3D", true, false):
			var gm: MeshInstance3D = mi
			if gm.material_override != null:
				continue
			for si in gm.mesh.get_surface_count():
				var am: Material = gm.mesh.surface_get_material(si)
				if am == null or Ep2Pbr._base_name(String(am.resource_name)) != "Brass":
					continue
				var om: StandardMaterial3D = gm.get_surface_override_material(si) as StandardMaterial3D
				var lin: Color = om.albedo_color.srgb_to_linear() if om != null else Color.BLACK
				bronze_seen += 1
				if om == null or absf(lin.r * bmean.r - want_b.r) > 0.01 or absf(lin.g * bmean.g - want_b.g) > 0.01 or om.metallic < 0.75:
					bronze_bad.append("%s#%d" % [gm.name, si])
		check("...its brass is the Colt's own period bronze, metal kept high in the yard", bronze_seen > 0 and bronze_bad.is_empty(),
			"seen %d, off %s" % [bronze_seen, str(bronze_bad)])
		# the gunner looks from Gat_Eye over the drum to the muzzle: no part of the gun may stand in that line (pitch frame)
		var a: Vector3 = eye.position
		var b: Vector3 = muzzle.position
		var worst: float = 1.0e9
		var pm: MeshInstance3D = pitch.find_child("Gat_Pitch_geo", true, false) as MeshInstance3D
		if pm == null:
			for c in pitch.get_children():
				if c is MeshInstance3D:
					pm = c
		if pm != null:
			for si in pm.mesh.get_surface_count():
				var verts: PackedVector3Array = pm.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for vv in verts:
					var v: Vector3 = pm.transform * vv
					if v.x < a.x + 0.05 or v.x > b.x - 0.05 or absf(v.z) > 0.3:
						continue
					var t: float = (v.x - a.x) / (b.x - a.x)
					var line_y: float = lerpf(a.y, b.y, t)
					worst = minf(worst, line_y - v.y)
		check("the gunner's sightline from the eye to the muzzle clears the drum and the breech", worst > 0.005, "closest %.3f m" % worst)
	print("EP2_PBR: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
