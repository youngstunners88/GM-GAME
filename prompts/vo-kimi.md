Kimi K3 — quick code + content check (Godot 4.3), concise, defects only.

TASK: Lil Blunt (chill weed-nugget hero) currently has ONE voice bark per reaction.
Expanding each to 3 variations + raising bark volume. Two parts:

1) play_bark(name, cooldown) in audio_manager.gd currently loads
   res://src/assets/sounds/voice/<name>(.ogg/.mp3) and plays it on a SFX-bus
   AudioStreamPlayer at unity gain. Plan: (a) set _bark_player.volume_db = 6.0
   (founder: "VO too quiet"); (b) pick a RANDOM existing variant among <name>,
   <name>_2, <name>_3 (probe ResourceLoader/_resolve_audio, collect those that
   exist, randi pick). Cooldown is keyed on the BASE name so variants share one
   cooldown. Flag: any pitfall with per-id cooldown vs variant selection, node
   leak, or the "missing file = silent no-op" contract.

2) Line vocabulary (custom voice, chill/positive/cute, NOT aggressive; 1-4 words):
   hurt: "Ow— okay." / "Oof— my bad." / "Easy, easy."
   attack(defeat enemy): "Yo! Got 'em!" / "Boom— down!" / "Too easy!"
   collect(major): "Ohh, nice." / "Sweet, that's mine." / "Stackin' up!"
   boss_hype: "Heh— let's gooo." / "Alright, big guy." / "Show time."
   death: "Welp. I'm out." / "Aw, man…" / "Catch me next round."
   Flag any line that reads aggressive/off-brand for a chill weed mascot.
