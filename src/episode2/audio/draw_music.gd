class_name Ep2DrawMusic
extends RefCounted
## Founder-supplied draw/road recording. Token pairing restores the actual prior song/position.
const TRACK := "res://src/episode2/extras/audio/music/06_28_remastered.mp3"
const LAKE_TRACK := "res://src/episode2/extras/audio/music/gm_laker2.mp3"
static var token: int = -1
static var lake_token: int = -1
static func begin(owner: Node) -> void:
 finish_lake(owner)
 if token >= 0: return
 var am: Node = owner.get_node_or_null("/root/AudioManager")
 if am != null: token = am.push_music_override(TRACK)
static func finish(owner: Node) -> void:
 if token < 0: return
 var am: Node = owner.get_node_or_null("/root/AudioManager")
 if am != null: am.release_music_override_faded(token,0.6)
 token = -1
static func begin_lake(owner: Node) -> void:
 finish(owner)
 if lake_token >= 0:return
 var am: Node=owner.get_node_or_null("/root/AudioManager")
 if am != null:lake_token=am.push_music_override(LAKE_TRACK)
static func finish_lake(owner: Node) -> void:
 if lake_token < 0:return
 var am: Node=owner.get_node_or_null("/root/AudioManager")
 if am != null:am.release_music_override_faded(lake_token,0.6)
 lake_token=-1
