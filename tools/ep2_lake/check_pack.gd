extends SceneTree
## Empty-project validation of the actual imports distributed to players.
var failures: int = 0
var checks: int = 0
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok: failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:
  quit(1);return
 for path in args:
  check("pack below 190 MiB",FileAccess.get_file_as_bytes(path).size()<199229440)
  check("pack mounts",ProjectSettings.load_resource_pack(path,true))
 for name in ["tex_woods_floor.jpg","tex_woods_bark.jpg","tex_woods_bark_n.png","tex_woods_branch.png","tex_woods_fern.png"]:
  var texture:=load("res://src/episode2/assets/woods/"+name) as Texture2D
  check("shared forest texture ships "+name,texture!=null and texture.get_width()>0)
 for name in ["planks_weathered","stone_rustic"]:
  for channel in ["albedo","normal"]:
   var texture:=load("res://src/episode2/extras/pbr/"+name+"/"+channel+".jpg") as Texture2D
   check("streamed shore PBR texture "+name+"/"+channel,texture!=null and texture.get_width()>0)
 for part in ["rowing_skiff","landscape/shore_kit","logan"]:
  var path: String="res://src/episode2/extras/lake/"+part+".glb"
  check(part+" has no raw source fallback",not FileAccess.file_exists(path))
  var scene: PackedScene=load(path)
  check(part+" imported scene ships",scene!=null)
  if scene==null:continue
  var model:=scene.instantiate() as Node3D
  root.add_child(model)
  if part=="rowing_skiff":
   for socket in ["SeatContact","FloorContact","SternMooring","OarPivot_L","OarPivot_R","GripContact_L","GripContact_R","BladeContact_L","BladeContact_R"]:
    check("skiff rigid socket "+socket,model.find_child(socket,true,false)!=null)
   var widths: Array=[]
   for i in 18:
    var marker:=model.find_child("WaterCut_%02d"%i,true,false) as Node3D
    check("hull waterline section %02d"%i,marker!=null)
    if marker!=null:widths.append(marker.position.x)
   check("hull waterline has a tapered measured profile",widths.size()==18 and widths[0]==0 and widths[17]==0 and widths[8]>.4)
  elif part=="logan":
   var rigs:=model.find_children("*","Skeleton3D",true,false)
   var players:=model.find_children("*","AnimationPlayer",true,false)
   check("founder Logan retains 65-bone skin",rigs.size()==1 and rigs[0].get_bone_count()==65)
   check("founder Logan retains authored animation player",players.size()==1)
   if players.size()==1:
    for clip in ["Idle","Greet","Point","Approve"]:check("Logan source clip "+clip,players[0].has_animation(clip))
  else:
   for piece in ["FirA_Wood","FirA_Needles","FirB_Wood","FirB_Needles","YoungFir_Wood","YoungFir_Needles","Rush0_Blade","Driftwood"]:
    check("forest geometry "+piece,model.find_child(piece,true,false)!=null)
  for node in model.find_children("*","MeshInstance3D",true,false):
   if node.mesh==null:continue
   for i in node.mesh.get_surface_count():
    var m:=node.mesh.surface_get_material(i) as StandardMaterial3D
    check(part+" material imports",m!=null)
    if m!=null and m.albedo_texture!=null:check(part+" albedo resolves",m.albedo_texture.get_width()>0)
  model.free()
 print("LAKE_PACK: ALL PASS (",checks," checks)" if failures==0 else "LAKE_PACK: FAILED "+str(failures))
 quit(0 if failures==0 else 1)
