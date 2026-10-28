extends Node
var out := "/workspace/work/pause-save/views"
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("out="): out=arg.substr(4)
 process_mode = Node.PROCESS_MODE_ALWAYS
 DirAccess.make_dir_recursive_absolute(out)
 StateMachine.change_state(StateMachine.State.TRANSITIONING)
 var level: Node = load(GameManager.LEVEL_SEQUENCE[0]).instantiate()
 get_tree().root.add_child.call_deferred(level)
 await get_tree().process_frame
 await get_tree().process_frame
 await shot("01-stage-controls")
 var pm: Node = level.get_node("PauseMenu")
 pm.toggle()
 await shot("02-stage-pause")
 var rows: Dictionary = {}
 for b in pm.get_node("VBox").get_children():
  if b is Button: rows[b.name] = b.get_global_rect().get_center().y
 print("PAUSE_ROWS ",JSON.stringify(rows))
 pm._on_resume_pressed();level.queue_free();await get_tree().process_frame
 if not StateMachine.is_playing():
  StateMachine.change_state(StateMachine.State.TRANSITIONING);StateMachine.change_state(StateMachine.State.PLAYING)
 GameManager.ep2_story_unlocked=true
 var entry: Node=load(GameManager.EPISODE2_SCENE).instantiate()
 add_child(entry);await get_tree().process_frame
 entry._root.get_active().set_physics_process(false)
 await shot("03-episode2-controls")
 entry._open_pause();entry._run_controls.save_button.pressed.emit()
 await shot("04-episode2-save")
 entry._close_pause();entry.queue_free();await get_tree().process_frame
 print("PAUSE_SAVE_REVIEW: DONE");get_tree().quit()
func shot(label: String) -> void:
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
