extends Node
func _ready() -> void:
 var c=load("res://src/episode2/chamber/logans_lake.tscn").instantiate();add_child(c);c.setup();c.set_physics_process(false)
 print("WORLD_ROOT ",c._cabin.root.global_transform)
 var shell=c._cabin.root.get_node("CabinShell")
 for mi in shell.find_children("*","MeshInstance3D",true,false):
  print("WORLD_SHELL ",mi.global_transform," bounds=",mi.mesh.get_aabb())
 print("TREES ",c._landscape.tree_instances)
 get_tree().quit()
