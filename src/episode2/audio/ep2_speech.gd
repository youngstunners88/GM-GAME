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

const GAP := 0.12                    # the breath between one speaker's last word and the next line


## True when this line will actually be heard (its recorded take is loadable right now).
static func voiced(id: String) -> bool:
	return id != "" and Ep2TownVoiceBank.stream(id) != null


## Seconds a spoken line holds the conversation: the take + GAP when it is voiced, a reading time when it is only captioned.
static func pace(id: String, text: String) -> float:
	var take: AudioStream = Ep2TownVoiceBank.stream(id) if id != "" else null
	if take != null:
		return take.get_length() + GAP
	return read_seconds(text)


## The fallback reading time for a caption that has no take behind it.
static func read_seconds(text: String) -> float:
	return clampf(1.3 + float(text.length()) * 0.052, 2.4, 6.2)
