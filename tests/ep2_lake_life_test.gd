extends Node
var fails := 0
func check(label: String, ok: bool) -> void:
 if not ok:fails+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready() -> void:
 check("basin surface area grows by more than two and a half times",Ep2LakeLandform.RADIUS_X*Ep2LakeLandform.RADIUS_Z/(27.0*33.0)>2.5)
 check("expanded eastern basin has a recessed bed",Ep2LakeLandform.terrain_height(85,20)<-.3)
 var flock := preload("res://src/episode2/art/ep2_trail_vultures.gd").new()
 add_child(flock)
 var before: Vector3=flock.birds[0].position
 flock._process(1)
 check("five vultures circle above the approach",flock.birds.size()==5 and flock.birds[0].position.distance_to(before)>1 and flock.birds[0].position.y>20)
 var ambience := preload("res://src/episode2/art/ep2_lake_ambience.gd").new()
 add_child(ambience)
 ambience._process(1)
 var playing := 0
 for p in ambience.layers:
  if p.stream!=null and p.playing:playing+=1
 check("water insects and frogs are actual playing audio streams",playing==3)
 ambience.timer=0;ambience._process(.1)
 check("intermittent birds are an actual fourth audio layer",ambience.bird.playing)
 ambience.hide();ambience._process(.1)
 check("leaving the lake silences every ambient layer",not ambience.bird.playing and not ambience.layers.any(func(p):return p.playing))
 print("LAKE_LIFE: ",fails," failed")
 get_tree().quit(fails)
