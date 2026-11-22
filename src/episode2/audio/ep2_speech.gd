class_name Ep2Speech
extends RefCounted
## SPOKEN LINES WITHOUT SUBTITLES (founder 2026-11-01: "The conversations of the character have an awkward delay. Lets also remove
## the subtitles."). One place decides how long a spoken line holds the conversation and whether its words go on screen:
##
## - A line with a recorded take plays the take and shows NO caption. It holds the conversation for the take itself plus a short
##   breath (GAP), never for a reading time: the old pacing waited max(reading time, take + 0.55 s), which is the dead air the
##   founder heard between lines.
## - A line whose take is missing (no recording authored, or the streamed voice pack has not arrived) falls back to the old caption,
##   held for a reading time, so a failed download never turns a conversation into silence.
##
## Rooms ask `pace()` for the hold and pass `voiced()` to `Ep2FpsHud.speech()`, which records the line but draws nothing when voiced.
##
## 2026-11-22 (founder: "remove the subtitles", again): in town a line with no take is now SILENT, not captioned. The town rooms pass
## `hide_caption(id)` instead of `voiced(id)`; the old caption fallback only comes back with the dev switch below.

const GAP := 0.12                    # the breath between one speaker's last word and the next line

## Dev-only switch: draw a caption for a town line whose take is missing. OFF in every build (founder 2026-11-22 "remove the subtitles").
static var captions_for_missing_takes: bool = false


## True when the HUD must NOT draw this line's words: it is heard, or it has no take and the dev caption switch is off.
static func hide_caption(id: String) -> bool:
	return voiced(id) or not captions_for_missing_takes


## True when this line will actually be heard (its recorded take is loadable right now).
static func voiced(id: String) -> bool:
	return id != "" and Ep2TownVoiceBank.stream(id) != null


## A townsman's recorded line from his own mouth (a 3D player on him). Founder 2026-11-22 (two townsmen behind the shops, image5): "the
## music must duck" - only the announcer slot and the greetings ducked it, so the miners' talk was buried. Within HEARD_M of Lil Blunt the
## music dips TOWN_TALK_DUCK_DB for the take (the AudioManager duck, which waits for the last line before it lifts); chatter further off
## plays under the music untouched. Returns true when it ducked.
const HEARD_M := 12.0
const TOWN_TALK_DUCK_DB := -12.0


static func play_3d(player: AudioStreamPlayer3D, take: AudioStream, listener_distance: float) -> bool:
	if player == null or take == null:
		return false
	player.stream = take
	player.play()
	if listener_distance > HEARD_M or not player.is_inside_tree():
		return false
	var am: Node = player.get_node_or_null("/root/AudioManager")
	if am == null or not am.has_method("duck_for_speech"):
		return false
	am.duck_for_speech(take.get_length(), TOWN_TALK_DUCK_DB)
	return true


## Seconds a spoken line holds the conversation: the take + GAP when it is voiced, a reading time when it is only captioned.
static func pace(id: String, text: String) -> float:
	var take: AudioStream = Ep2TownVoiceBank.stream(id) if id != "" else null
	if take != null:
		return take.get_length() + GAP
	return read_seconds(text)


## The fallback reading time for a caption that has no take behind it.
static func read_seconds(text: String) -> float:
	return clampf(1.3 + float(text.length()) * 0.052, 2.4, 6.2)
