extends Node
func _ready() -> void:
 var c: LogansLakeChamber=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 add_child(c)
 c.setup()
 c.set_physics_process(false)
 await get_tree().process_frame
 print("SKIFF_READY ",c._skiff!=null and c._skiff.ready_art)
 c._staged=true
 c._talk_t=0.0
 for i in 60*55:
  c.step(1.0/60.0)
  if i%600==0:print("BOAT_STATE t=",i/60.0," state=",c._skiff.state," actor=",c._logan.position," boat=",c._skiff.boat.position)
 var b: Ep2LoganSkiff=c._skiff
 print("BOAT_CONTACT left=",b.palm_position("Left").distance_to(b.grips[0].global_position)," right=",b.palm_position("Right").distance_to(b.grips[1].global_position)," seat=",b.seat_error()," phase=",b.stroke_phase," distance=",b.circuit_distance)
 get_tree().quit()
