extends SceneTree
var vp:SubViewport
var session
var trail
var audio
var failed:=0
func _initialize()->void:
 var args=OS.get_cmdline_user_args()
 if not args.is_empty():ProjectSettings.load_resource_pack(args[0],false)
 call_deferred("run")
func check(label:String,ok:bool)->void:
 if not ok:failed+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func run()->void:
 await process_frame
 root.content_scale_size=Vector2i(640,360)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
 var sm=root.get_node("StateMachine")
 sm.change_state(sm.State.TRANSITIONING);sm.change_state(sm.State.PLAYING)
 audio=root.get_node("AudioManager")
 var container=SubViewportContainer.new()
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true
 root.add_child(container)
 vp=SubViewport.new();vp.size=Vector2i(640,360);container.add_child(vp)
 session=load("res://src/episode2/session/ep2_session_root.tscn").instantiate();vp.add_child(session)
 session.set_process(false)
 session.armory=load("res://src/episode2/chamber/ep2_armory_state.gd").post_hideout()
 trail=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
 session.add_child(trail);session._active=trail;session._wire_chamber(trail);trail.setup();trail.set_physics_process(false)
 session._drive_prebuild(1e9)
 var lake=session._pb_node
 for i in 200:trail.preview_lake(lake)
 check("lake and supplied Logan preview before shore",trail._lake_preview.has_node("Logan") and trail._preview_copied.size()>10)
 var music=load("res://src/episode2/audio/draw_music.gd")
 music.begin_town(trail)
 check("town score pairs the original theme with GMTown",audio._region_tracks.size()==2 and audio._region_tracks[1]==music.TOWN_TRACK)
 var opening_modes={}
 for view in root.find_children("*","SubViewport",true,false):
  opening_modes[view]=view.render_target_update_mode
  view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 print("ARRIVAL_WEB_UNLOCK")
 while not Input.is_key_pressed(KEY_F9):await process_frame
 print("ARRIVAL_WEB_ACK")
 while Input.is_key_pressed(KEY_F9):await process_frame
 audio.play_track_from(load("res://src/episode2/chamber/woods_quad.gd").TOWN_MUSIC,0,0)
 music.begin_town(trail)
 var a=audio.current_music_player
 var deadline=Time.get_ticks_msec()+int((a.stream.get_length()+12)*1000)
 print("ARRIVAL_WEB_LINGER ",a.stream.get_length()," seconds natural boundary")
 while audio.current_music_player==a and Time.get_ticks_msec()<deadline:
  await create_timer(.2).timeout
 check("town automatically alternates with overlapping decks after real playback",audio._last_track==music.TOWN_TRACK and audio._retiring.has(a))
 trail._place_at_distance(trail._route_total-80)
 trail._look_yaw=trail._travel_yaw;trail._look_pitch=-.025
 trail._blend_lake_light();trail._update_camera(0);trail._sync_visuals()
 for view in opening_modes:
  if is_instance_valid(view):view.render_target_update_mode=opening_modes[view]
 music.begin_trail(trail)
 check("trail starts through region crossfade",audio._last_track==music.TRACK and not audio._retiring.is_empty())
 for distance in [80.,45.,15.]:
  trail._place_at_distance(trail._route_total-distance)
  trail._look_yaw=trail._travel_yaw;trail._look_pitch=-.025
  trail._tick(0);trail._blend_lake_light();trail._update_camera(0);trail._sync_visuals()
  await frames(4)
  await shot("approach-%d"%int(distance))
 var approach_deck=audio.current_music_player
 check("lake score begins before shore",audio._last_track==music.LAKE_TRACK)
 trail._begin_shore()
 trail._tick_shore(3)
 check("shore remains mounted while horse drinks",not trail.is_resolved() and absf(trail.eye_height-trail.MOUNTED_EYE)<.001)
 trail._tick_shore(trail.SHORE_SECONDS-3)
 trail._blend_lake_light();trail._update_camera(0);trail._sync_visuals()
 var expected_camera=trail.lake_transform().affine_inverse()*trail._camera.global_transform
 await frames(4)
 await shot("shore-before-handoff")
 session._chain_id="logans_lake";session._enter_chamber_chained(0)
 var arrived=session.get_active();arrived.set_physics_process(false)
 check("same lake instance activates without restarting score",arrived==lake and audio.current_music_player==approach_deck)
 check("lake handoff preserves the physical eye and gaze",arrived._camera.global_transform.is_equal_approx(expected_camera))
 await frames(4)
 await shot("lake-arrival")
 print("ARRIVAL_WEB_RESULT ",JSON.stringify({"failed":failed,"checks":8,"deck":audio._last_track,"position":str(arrived._player_pos),"playback_seconds":audio.get_music_position(),"backend_seconds":audio.current_music_player.get_playback_position()}))
 print("ARRIVAL_WEB_DONE")
func frames(n:int)->void:
 for i in n:await RenderingServer.frame_post_draw
func shot(label:String)->void:
 var modes={}
 for view in root.find_children("*","SubViewport",true,false):
  modes[view]=view.render_target_update_mode;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 print("ARRIVAL_WEB_FRAME ",label)
 while not Input.is_key_pressed(KEY_F9):await process_frame
 print("ARRIVAL_WEB_ACK")
 while Input.is_key_pressed(KEY_F9):await process_frame
 for view in modes:
  if is_instance_valid(view):view.render_target_update_mode=modes[view]
