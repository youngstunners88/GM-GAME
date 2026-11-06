extends Node3D
func _ready() -> void:
 var yard := Ep2StableYard.new()
 add_child(yard)
 yard._build_actor("Dude", Ep2StableYard.DUDE, 1.84, Ep2StableYard.DUDE_PATH, 0.75, 9, [])
 yard._build_horses([])
 var dude: Ep2TownFolk = yard.actors[0]
 var failures := 0
 for cycle in 2:
  dude.place(Ep2StableYard.RIDE_MOUNT)
  yard._begin_mount()
  var max_jump := 0.0
  var max_turn := 0.0
  var min_dot := 1.0
  var ridden := false
  for frame in 30000:
   var before: Vector3 = dude.position
   var yaw: float = dude.rotation.y
   if yard._ride_state == "mount": yard._tick_mount(dude, 1.0/60.0)
   elif yard._ride_state == "ride":
    ridden = true
    yard._tick_ride(dude, 1.0/60.0, Vector3.ZERO)
    min_dot = minf(min_dot, dude.basis.z.dot(yard.horses[0].basis.x))
   elif yard._ride_state == "dismount": yard._tick_dismount(dude, 1.0/60.0, Vector3.ZERO)
   else: break
   max_jump = maxf(max_jump, before.distance_to(dude.position))
   max_turn = maxf(max_turn, absf(wrapf(dude.rotation.y-yaw, -PI, PI)))
  var ok: bool = ridden and yard._ride_state == "" and dude.position.distance_to(Ep2StableYard.RIDE_MOUNT) < .001 and min_dot > .999 and max_jump < .1 and max_turn < .25
  print("MOUNT_CYCLE ",cycle," ",ok," max_step=",max_jump," max_yaw=",max_turn," forward=",min_dot)
  if not ok: failures += 1
 print("EP2_MOUNT_ALIGNMENT: ALL PASS" if failures == 0 else "EP2_MOUNT_ALIGNMENT: FAILED")
 get_tree().quit(failures)
