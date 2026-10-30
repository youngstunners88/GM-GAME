extends Node
class Destination extends Node3D:
 var _visuals:Node3D
 func _init():
  _visuals=Node3D.new();add_child(_visuals)
 func _people()->void:pass
 func _build_skiff()->void:pass
var failed:=0
var checks:=0
func check(label:String,ok:bool)->void:
 checks+=1
 if not ok:failed+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready()->void:
 var trail=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 add_child(trail);trail.setup();trail.set_physics_process(false)
 var destination=Destination.new();add_child(destination)
 var anonymous=Node3D.new();destination._visuals.add_child(anonymous)
 var ground=MeshInstance3D.new();ground.name="ShoreAndMountain";ground.mesh=BoxMesh.new();destination._visuals.add_child(ground)
 for i in 20:trail.preview_lake(destination)
 check("anonymous roots copy exactly once",trail._lake_preview.get_child_count()==2)
 check("preview reuses the arrival transform",trail._lake_preview.transform.is_equal_approx(trail.lake_transform()))
 check("ground clears the old desert",trail._sand_material.get_shader_parameter("lake_visible"))
 var late=Node3D.new();late.name="Logan";destination._visuals.add_child(late)
 trail.preview_lake(destination)
 check("a later streamed Logan joins the existing preview",trail._lake_preview.has_node("Logan"))
 check("the source character remains in the prebuilt room",late.get_parent()==destination._visuals)
 check("cloned scripts cannot run duplicate story logic",trail._lake_preview.get_node("Logan").process_mode==Node.PROCESS_MODE_DISABLED)
 var body=Node3D.new();body.name="Player";destination._visuals.add_child(body)
 for i in 200:trail.preview_lake(destination)
 check("preview never shows a duplicate player",not trail._lake_preview.has_node("Player"))
 var obsolete=trail._preview_copied[anonymous.get_instance_id()]
 anonymous.free()
 destination._visuals.add_child(Node3D.new())
 for i in 20:trail.preview_lake(destination)
 check("streamed root replacement removes the old copy without growing scenery",trail._lake_preview.get_child_count()==3 and not is_instance_valid(obsolete))
 print("EP2_LAKE_PREVIEW: ",checks," checks, ",failed," failed")
 get_tree().quit(failed)
