extends Node3D
## Layered original shore ambience; loaded lazily from the existing extras pack.
var layers: Array[AudioStreamPlayer3D] = []
var bird: AudioStreamPlayer3D
var timer := 3.0
func _ready() -> void:
 for kind in ["water","insects","frogs"]:
  var player := AudioStreamPlayer3D.new()
  player.name = kind.capitalize()
  player.position = {"water":Vector3(1,0,18),"insects":Vector3(-12,2,5),"frogs":Vector3(5,0,30)}[kind]
  player.volume_db = -8.0 if kind=="water" else -15.0
  player.max_distance=110;player.unit_size=18
  add_child(player);layers.append(player)
 bird=AudioStreamPlayer3D.new();bird.position=Vector3(-8,9,15);bird.volume_db=-17;bird.unit_size=25;bird.max_distance=140;add_child(bird)
func _process(delta: float) -> void:
 if not is_visible_in_tree():
  for p in layers: p.stop()
  bird.stop()
  return
 for i in layers.size():
  var p: AudioStreamPlayer3D = layers[i]
  if p.stream==null:
   var path: String = "res://src/episode2/extras/audio/lake/"+["water","insects","frogs"][i]+".ogg"
   if ResourceLoader.exists(path):
    p.stream=load(path)
    if p.stream is AudioStreamOggVorbis: p.stream.loop=true
  if p.stream!=null and not p.playing:p.play()
 timer-=delta
 if timer<=0 and not bird.playing:
  bird.stream=load("res://src/assets/sounds/ep2_bird_call_"+str(1+randi()%3)+".mp3")
  bird.pitch_scale=randf_range(.9,1.08);bird.play();timer=randf_range(9,19)
