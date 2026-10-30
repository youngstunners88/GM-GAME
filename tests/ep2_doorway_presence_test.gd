extends Node
var checks := 0
var failed := 0
func check(label: String,ok: bool) -> void:
	checks+=1
	if not ok:failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)

func blocked(root: Node3D,from: Vector3,to: Vector3) -> bool:
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D=node
		if mesh.mesh==null:continue
		var a: Vector3=mesh.to_local(from)
		var b: Vector3=mesh.to_local(to)
		var faces: PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:
				return true
	return false

func _ready() -> void:
	var jail: Node3D=load(Ep2Extras.JAIL).instantiate()
	add_child(jail)
	for x in [-0.4,0.0,0.4]:
		check("visible office throughout walkable doorway lane x=%.1f"%x,not blocked(jail,Vector3(x,1.55,0.8),Vector3(x,1.55,-2.2)))
	check("wall control still blocks a sightline outside the opening",blocked(jail,Vector3(1.0,1.55,0.8),Vector3(1.0,1.55,-2.2)))
	check("office and cell geometry remain in the same building",jail.find_child("Bldg_Jail",true,false)!=null and Ep2GoldTown.FOOTPRINT.Bldg_Jail==[7.4,8.6,0.75])
	jail.free()
	print("EP2_DOORWAY_PRESENCE: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
