extends Node
## Contacts use measured landmarks on the supplied scoped showcase, not points attached to the hands.
var checks := 0
var failures := 0
var max_error := 0.0
const POSE := preload("res://src/episode2/actors/ep2_armory_pose.gd")
const SOLVE := preload("res://src/episode2/actors/ep2_ranch_pose.gd")
const GRIP := Vector3(0.0035, 0.1416, -0.2140)
const FORE := Vector3(0.0035, 0.1671, -0.0012)
const MODEL_SCALE := 1.175
func check(label: String, ok: bool) -> void:
 checks += 1
 if not ok:
  failures += 1
  print("[FAIL] ",label)
func contacts(f: Ep2TownFolk, label: String) -> void:
 var sk: Skeleton3D = f.model.find_children("*", "Skeleton3D", true, false)[0]
 sk.force_update_all_bone_transforms()
 var gun: Node3D = f.held_prop("Sharps")
 var attachment: BoneAttachment3D = gun.get_parent()
 var frame: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(attachment.bone_name)) * gun.transform
 for side in ["Left", "Right"]:
  var local_target: Vector3 = (FORE-GRIP)*MODEL_SCALE + Vector3(0,-0.065,-0.03) if side=="Left" else Vector3(0,-0.015,-0.055)
  var target: Vector3 = frame * local_target
  var wrist: Vector3 = sk.global_transform * sk.get_bone_global_pose(SOLVE._find(sk, side+"Hand")).origin
  var error: float = wrist.distance_to(target)
  max_error = maxf(max_error,error)
  check(label+" "+side+" wrist to measured contact = "+str(error), error<0.012)
func _ready() -> void:
 await get_tree().process_frame
 var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
 add_child(c);c.setup(0,[],0);c.set_physics_process(false)
 var f: Ep2TownFolk = c._rich
 c._on_sharps_lifted(true)
 var ap: AnimationPlayer=f.anim_player()
 ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 for clip in ["Idle","GroundedWalk","Talk","Reach","PutDown","InspectRifle"]:
  f.hold_clip(clip);f.play_clip(clip)
  var name: String=ap.assigned_animation
  check(clip+" uses a held variant", name.begins_with("Sharps") or name=="InspectRifle")
  ap.play(name,0.0);ap.advance(0.3)
  for heading in 4:
   f.rotation.y=float(heading)*PI*0.5
   for phase in [0.0,0.25,0.5,0.75]:
    ap.seek(ap.current_animation_length*phase,true);ap.advance(0.0)
    contacts(f,clip+" "+str(heading)+" "+str(phase))
 c._beat=c.Beat.GEARED;c._show_active=false;c._show_blocks_control=false;c._hold=0
 c._player_pos=f.global_position+Vector3(0,0,2)
 check("already-held rifle can react", c._law.retaliation.begin(c,"rich",f))
 for frame in 45:
  c.step(1.0/60.0)
  if frame>=18: contacts(f,"aim/fire "+str(frame))
 c._law.retaliation.reset()
 print("EP2_RICH_GRIP: %d checks, %d failures, max_error_m=%.6f" % [checks,failures,max_error])
 print("EP2_RICH_GRIP: ALL PASS" if failures==0 else "EP2_RICH_GRIP: FAILED")
 c.queue_free();await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
