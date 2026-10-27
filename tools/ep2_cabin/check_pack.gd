extends SceneTree
## Validate only shipped imports, from an empty project with no source fallback.
const DIR := "res://src/episode2/extras/lake/cabin/"
var checks: int=0
var failures: int=0
func check(label: String,ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:quit(1);return
 for p in args:
  check("pack below190MiB",FileAccess.get_file_as_bytes(p).size()<199229440)
  check("pack mounts",ProjectSettings.load_resource_pack(p,true))
 for name in ["cabin","details"]:
  var path: String=DIR+name+".glb"
  check(name+" source cannot mask missing imports",not FileAccess.file_exists(path))
  var packed:=load(path)as PackedScene
  check(name+" imported scene ships",packed!=null)
  if packed==null:continue
  var model:=packed.instantiate()as Node3D;root.add_child(model)
  if name=="cabin":
   var mi:=model.find_child("LoganCabinShell",true,false)as MeshInstance3D
   check("single-storey cabin has metre-scale bounds",mi!=null and mi.mesh.get_aabb().size.x>6.0 and mi.mesh.get_aabb().size.y>4.4)
  else:
   for socket in ["LPFace","GMFace","GMWordmark","BTCFace","PosterRH","PosterJack","PanInterior","TableSurface","PorchSurface","RampTop","RampFoot","ReserveLabel","LedgerFace","LanternLight"]:
    check("rigid cabin contact "+socket,model.find_child(socket,true,false)!=null)
   for piece in ["GoldPan0","GoldPan1","ProspectingTabletop","OreSortingSlate","LanternBracket","LanternChain"]:
    check("authored cabin geometry "+piece,model.find_child(piece,true,false)!=null)
   for i in 7:check("pan nugget geometry%d"%i,model.find_child("Nugget%d"%i,true,false)!=null)
   for i in 3:check("exterior nugget geometry%d"%i,model.find_child("ExteriorNugget%d"%i,true,false)!=null)
   for i in 8:check("BTC coin contact%d"%i,model.find_child("CoinFace%d"%i,true,false)!=null)
  for n in model.find_children("*","MeshInstance3D",true,false):
   for i in n.mesh.get_surface_count():
    var mat:=n.mesh.surface_get_material(i)as StandardMaterial3D
    check(name+" material resolves",mat!=null)
    if mat!=null and mat.albedo_texture!=null:check(name+" texture resolves at1K",mat.albedo_texture.get_width()>0 and mat.albedo_texture.get_width()<=1024)
  model.free()
 for path in [DIR+"liquidity_sign.png",DIR+"goldmine_wordmark.png",DIR+"btc_reserves.png","res://src/episode2/assets/textures/logos/logo_gold_mine.png","res://src/episode2/assets/textures/tex_btc_coin.png","res://src/episode2/extras/town/posters/poster_rh.png","res://src/episode2/extras/town/posters/poster_jack_hammer.jpg"]:
  var tex:=load(path)as Texture2D
  check("canonical signage texture ships "+path.get_file(),tex!=null and tex.get_width()>0)
 print("CABIN_PACK: ALL PASS (",checks," checks)"if failures==0 else "CABIN_PACK: FAILED "+str(failures));quit(0 if failures==0 else 1)
