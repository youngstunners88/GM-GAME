extends Node
var failures := 0
var checks := 0
func check(label: String, ok: bool) -> void:
 checks += 1
 print("[PASS] " + label if ok else "[FAIL] " + label)
 if not ok: failures += 1
func _ready() -> void:
 await get_tree().process_frame
 GameManager.reset_session()
 var session := Ep2SessionRoot.new()
 add_child(session)
 session.set_process(false)
 session.configure([{"chamber": "woods_quad"}], false)
 session._enter_chamber()
 var c: WoodsQuadChamber = session._active
 c.set_physics_process(false)
 c.debug_invulnerable = true
 c._beat = c.Beat.DROPOFF
 c._show_active = false
 c._show_blocks_control = false
 c._hold = 0
 var entry: Vector3 = c._player_pos
 for row in [["dude", "Dude"], ["stable_assistant", "StableAssistant"], ["sheriff", "OfficeSheriff"], ["minister", "OfficeMikeDean"]]:
  var f: Ep2TownFolk = c._visuals.find_child(row[1], true, false)
  for encounter in 2:
   c._player_pos = f.global_position + Vector3(0,0,-2 if row[0]=="sheriff" else 2)
   var d: Vector3 = f.global_position + Vector3(0,1.3,0) - (c._player_pos + Vector3(0,c.eye_height,0))
   c._look_yaw=atan2(d.x,d.z);c._look_pitch=atan2(d.y,Vector2(d.x,d.z).length())
   c._update_camera(0)
   c._on_player_shot()
   check(str(row[0])+" woods hit starts protected draw", c._protected_trace.retaliation.active)
   if not c._protected_trace.retaliation.active: continue
   var before: int = c._protected_trace.retaliation.shots
   for i in 10: c._on_player_shot()
   for i in 100: c.step(1.0/60.0)
   await get_tree().process_frame
   check(str(row[0])+" woods single decisive shot", c._protected_trace.retaliation.shots == before+1)
   check(str(row[0])+" woods restart preserves active chamber", session._active==c and c._player_pos.is_equal_approx(entry) and not c._resolved and not f.dead)
   check(str(row[0])+" woods response resets", not c._protected_trace.retaliation.active and c.has_player_control())
 session.queue_free()
 await get_tree().process_frame
 print("EP2_PROTECTED_WOODS: %d checks, %d failures" % [checks,failures])
 print("EP2_PROTECTED_WOODS: ALL PASS" if failures == 0 else "EP2_PROTECTED_WOODS: FAILED")
 get_tree().quit(1 if failures else 0)
