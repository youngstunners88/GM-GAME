extends Node
## Actual imported meshes and final skeletal contact, not an assertion of the
## same target coordinates used to place the oars. Run alongside the story gate.
var failures: int = 0
var checks: int = 0
func check(label: String, ok: bool) -> void:
 checks += 1
 if not ok: failures += 1
 print("[PASS] " + label if ok else "[FAIL] " + label)
func advance(c: LogansLakeChamber, seconds: float) -> void:
 for i in int(seconds * 60): c.step(1.0 / 60.0)
func drawn_ground(c: LogansLakeChamber, p: Vector3) -> float:
 var ground:=c._visuals.get_node("ShoreAndMountain") as MeshInstance3D
 var arrays:=ground.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,indices.size(),3):
  var a: Vector3=ground.to_global(vertices[indices[i]])
  var b: Vector3=ground.to_global(vertices[indices[i+1]])
  var d: Vector3=ground.to_global(vertices[indices[i+2]])
  if p.x<minf(a.x,minf(b.x,d.x)) or p.x>maxf(a.x,maxf(b.x,d.x)) or p.z<minf(a.z,minf(b.z,d.z)) or p.z>maxf(a.z,maxf(b.z,d.z)):continue
  var hit=Geometry3D.segment_intersects_triangle(p+Vector3(0,20,0),p-Vector3(0,10,0),a,b,d)
  if hit!=null:return hit.y
 return INF
func _ready() -> void:
 var c: LogansLakeChamber=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 add_child(c);c.setup();c.set_physics_process(false)
 await get_tree().process_frame
 check("new streamed forest kit is actually instantiated", c._landscape.upgraded)
 check("woodland groves retain a bounded shared-mesh instance count", c._landscape.tree_instances >= 90 and c._landscape.tree_instances <= 175)
 var trunks_clear: bool=true
 for node in c._landscape.flora.get_children():
  if node is MultiMeshInstance3D and str(node.name).ends_with("_Wood"):
   for i in node.multimesh.instance_count:
    var p: Vector3=node.multimesh.get_instance_transform(i).origin
    if p.x > -14 and p.x < -2.5: trunks_clear=false
 check("new tree trunks leave the entire walked shore corridor clear", trunks_clear)
 check("Logan and cargo meet the actual drawn ground at their unchanged marks", absf(drawn_ground(c,c.LOGAN_MARK)-c.LOGAN_MARK.y)<.025 and absf(drawn_ground(c,c.STAGING_MARK)-c.STAGING_MARK.y)<.025 and absf(c.terrain_height(c.LOGAN_MARK.x,c.LOGAN_MARK.z))<.001)
 check("continuous basin is recessed below the actual water", c.terrain_height(24,20)<-1.5 and c.terrain_height(24,20)<Ep2LoganSkiff.WATER_Y)
 check("outflow meanders while keeping a recessed bed", absf(Ep2LakeLandform.flow_center(72)-24)>.5 and c.terrain_height(Ep2LakeLandform.flow_center(72),72)<-.5)
 check("boat art is mounted without replacing the supplied Logan skin", c._skiff!=null and c._skiff.ready_art and c._skiff._sk.get_bone_count()==65)
 var b: Ep2LoganSkiff=c._skiff
 if b==null or not b.ready_art:
  get_tree().quit(1);return
 check("both rigid oars have independently authored grip and blade nodes", b.oars.size()==2 and b.oars[0]!=b.oars[1] and b.grips[0].get_parent()==b.oars[0] and b.blades[1].get_parent()==b.oars[1])
 check("open hull has an actual measured, tapered moving water cut", b.hull_widths.size()==18 and b.hull_widths[0]==0 and b.hull_widths[17]==0 and b.hull_widths[8]>.4 and b.hull_widths[8]<.64 and c._landscape.water_material.get_shader_parameter("boat_present")==true)
 check("boat floats across waterline with an open hull above it", b.boat.position.y-.30<b.WATER_Y and b.boat.position.y+.30>b.WATER_Y)
 advance(c,2)
 check("arrival keeps Logan on shore and boat visibly moored", b.state==b.State.MOORED and c._logan.position.distance_to(c.LOGAN_MARK)<.001 and b._rope.visible and not b._wake.visible)
 c._staged=true;c._advance_to(c.Beat.HANDOFF)
 advance(c,7)
 check("Logan waits through his handoff dialogue before departing", b.state==b.State.MOORED)
 advance(c,2)
 check("handoff starts a physical dock approach before rowing", b.state==b.State.WALK_TO_BOAT and b.circuit_distance==0)
 advance(c,19)
 check("Logan boards and rows the boat after walking to it", b.state==b.State.ROW and b.circuit_distance>0)
 check("mooring is released and wake appears only after boarding", not b._rope.visible and b._wake.visible)
 var start: Vector3=b.boat.position
 var max_contact: float=0
 var max_seat: float=0
 var max_foot: float=0
 var max_length: float=0
 var power_blade: float=99
 var recovery_blade: float=-99
 var left_grip_motion: float=0
 var grip_start: Vector3=b.grips[0].position
 for i in 162:
  c.step(1.0/30.0)
  for side in ["Left","Right"]:
   var index: int=0 if side=="Left" else 1
   max_contact=maxf(max_contact,b.palm_position(side).distance_to(b.grips[index].global_position))
   var foot: Vector3=b._pose_world(side+"Foot").origin
   var expected: Vector3=b._floor.global_position+b.boat.global_basis*Vector3(-.15 if index==0 else .15,.12,0)
   max_foot=maxf(max_foot,foot.distance_to(expected))
   for chain in [[side+"Arm",side+"ForeArm"],[side+"ForeArm",side+"Hand"],[side+"UpLeg",side+"Leg"],[side+"Leg",side+"Foot"]]:
    var rest_length: float=b._rest_world(chain[0]).origin.distance_to(b._rest_world(chain[1]).origin)
    var drawn_length: float=b._pose_world(chain[0]).origin.distance_to(b._pose_world(chain[1]).origin)
    max_length=maxf(max_length,absf(rest_length-drawn_length))
  max_seat=maxf(max_seat,b.seat_error())
  left_grip_motion=maxf(left_grip_motion,b.grips[0].global_position.distance_to(b.boat.to_global(grip_start)))
  if b.stroke_phase>.08 and b.stroke_phase<.45: power_blade=minf(power_blade,b.blades[0].global_position.y)
  if b.stroke_phase>.68 and b.stroke_phase<.86: recovery_blade=maxf(recovery_blade,b.blades[0].global_position.y)
 print("ROWING_METRICS palms=",max_contact," seat=",max_seat," feet=",max_foot," limb_length=",max_length," power_blade=",power_blade," recovery_blade=",recovery_blade)
 check("both actual palms follow their rigid grips through two complete strokes", max_contact<.015 and left_grip_motion>.05)
 check("pelvis remains supported by the independently authored rowing seat", max_seat<.01)
 check("both boots stay supported on the actual footrest", max_foot<.01)
 check("no arm or leg bone is stretched to fake contact", max_length<.003)
 check("oar blades enter water on power and clear it on recovery", power_blade<b.WATER_Y-.01 and recovery_blade>b.WATER_Y+.10)
 check("rowing moves the skiff through the lake instead of waving on the spot", b.boat.position.distance_to(start)>1.5)
 c.set_physics_process(true);c.toggle_armory()
 var frozen_distance: float=b.circuit_distance
 var frozen_time: float=b._time
 await get_tree().create_timer(.15,true).timeout
 check("armory pause freezes boat travel, stroke clock and actor routine", get_tree().paused and b.circuit_distance==frozen_distance and b._time==frozen_time)
 c.toggle_armory();c.set_physics_process(false)
 c._on_setup()
 check("retry restores Logan, mooring and the original first-visit state", b.state==b.State.MOORED and b.circuit_distance==0 and not c.staging_complete() and c._logan.position.distance_to(c.LOGAN_MARK)<.001 and b._rope.visible and not b._wake.visible)
 print("LAKE_ART: ",checks," checks, ",failures," failed")
 c.queue_free();await get_tree().process_frame
 get_tree().quit(0 if failures==0 else 1)
