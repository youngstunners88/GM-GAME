extends Node
var checks: int=0
var failures: int=0
func check(label: String,ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("[PASS] "+label if ok else "[FAIL] "+label)
func walk(c: LogansLakeChamber,target: Vector3) -> bool:
 for i in 3600:
  var d: Vector3=target-c.get_player_position()
  if Vector2(d.x,d.z).length()<.15:
   c.set_move_input(Vector2.ZERO);return true
  c._look_yaw=atan2(d.x,d.z);c.set_move_input(Vector2(0,1));c.step(1.0/60.0)
 return false
func mesh_y(mi: MeshInstance3D,top: bool) -> float:
 var bb:=mi.mesh.get_aabb();var y: float=-INF if top else INF
 for i in 8:
  var p: Vector3=mi.to_global(bb.get_endpoint(i))
  y=maxf(y,p.y)if top else minf(y,p.y)
 return y
func surface(nodes: Array,from: Vector3,to: Vector3) -> Variant:
 var nearest=null;var distance: float=INF
 for node in nodes:
  var mi:=node as MeshInstance3D
  if mi==null or mi.mesh==null:continue
  for s in mi.mesh.get_surface_count():
   var a:=mi.mesh.surface_get_arrays(s)
   var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
   var n: int=ids.size() if not ids.is_empty()else v.size()
   for j in range(0,n,3):
    var p: Vector3=mi.to_global(v[ids[j]if not ids.is_empty()else j])
    var q: Vector3=mi.to_global(v[ids[j+1]if not ids.is_empty()else j+1])
    var r: Vector3=mi.to_global(v[ids[j+2]if not ids.is_empty()else j+2])
    var hit=Geometry3D.segment_intersects_triangle(from,to,p,q,r)
    if hit!=null and from.distance_to(hit)<distance:
     nearest=hit;distance=from.distance_to(hit)
 return nearest
func _ready() -> void:
 var c: LogansLakeChamber=load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
 add_child(c);c.setup();c.set_physics_process(false);await get_tree().process_frame
 var b: Ep2LoganCabin=c._cabin
 check("streamed cabin and detail kit actually build",b.ready_art and b.root!=null and b.kit!=null)
 if not b.ready_art:get_tree().quit(1);return
 check("exact LP sentence and Logan ownership are wired",b.root.get_meta("lp_sentence")=="Be a liquidity provider." and b.root.get_meta("ownership")=="LOGAN'S CABIN")
 check("canonical GM and BTC art are used",b.pictures.GMLogo.get_meta("source_texture")==b.GM and b.pictures.BTCEmblem.get_meta("source_texture")==b.BTC)
 check("both canonical wanted bills are used without substitution",b.pictures.WantedRH.get_meta("source_texture")==b.RH and b.pictures.WantedJackHammer.get_meta("source_texture")==b.JACK)
 var aspect: bool=true
 for image in b.pictures.values():
  var m:=image.material_override as StandardMaterial3D
  var quad:=image.mesh as QuadMesh
  if m==null or m.albedo_texture==null:aspect=false;continue
  aspect=aspect and absf(quad.size.x/quad.size.y-float(m.albedo_texture.get_width())/m.albedo_texture.get_height())<.006
 check("all signs/logos/posters retain their source aspect ratio",aspect)
 var shell:=b.root.get_node("CabinShell").find_children("*","MeshInstance3D",true,false)
 var house:=shell[0]as MeshInstance3D
 var ground:=c._visuals.get_node("ShoreAndMountain") as MeshInstance3D
 var support=surface([ground],b.root.position+Vector3(0,8,0),b.root.position-Vector3(0,3,0))
 check("actual cabin footing meets the actual terrain triangles",support!=null and absf(mesh_y(house,false)-support.y)<.04)
 check("cabin remains a small single-storey structure",house.mesh.get_aabb().size.x>6.0 and house.mesh.get_aabb().size.x<6.4 and house.mesh.get_aabb().size.y>4.4 and house.mesh.get_aabb().size.y<4.8)
 var tree_clear: bool=true
 for node in c._landscape.flora.get_children():
  if node is MultiMeshInstance3D and str(node.name).ends_with("_Wood"):
   for i in node.multimesh.instance_count:
    var p: Vector3=node.multimesh.get_instance_transform(i).origin
    if Ep2LakeLandform.cabin_clearance(p.x,p.z):tree_clear=false
 check("woodland trunks leave cabin and approach clear",tree_clear)
 var inventory: Dictionary=c.armory.snapshot().duplicate(true)
 check("ordinary movement reaches the woodland spur",walk(c,Vector3(-12.8,0,13)))
 check("ordinary movement reaches the courtyard",walk(c,Vector3(-16.6,1,13)))
 check("ordinary movement climbs the real porch ramp",walk(c,Vector3(-18.2,1.24,13)) and absf(c.get_player_position().y-1.24)<.03)
 var floor_nodes: Array=[]
 for mi in b.kit.find_children("Fixed_*","MeshInstance3D",true,false):floor_nodes.append(mi)
 var floor=surface(floor_nodes,c.get_player_position()+Vector3(0,.08,.04),c.get_player_position()+Vector3(0,-.15,.04))
 check("porch feet are supported by drawn deck geometry",floor!=null and absf(floor.y-c.get_player_position().y)<.025)
 check("cabin visit offers no remote staging or financial interaction",not c.start_rig() and not c.staging_complete())
 var wall: Vector3=c._collide(Vector3(-22,1,13))
 check("closed cabin body blocks the player",wall.x>=-20.101 or wall.z<=9.5 or wall.z>=16.5)
 var old: Vector3=c._player_pos;c._player_pos=Vector3(-27,1,19.95)
 var edge: Vector3=c._collide(Vector3(-27,1,20.05))
 check("yard edge stops movement without teleporting to the lake path",Vector2(edge.x+27,edge.z-19.95).length()<.2)
 c._player_pos=old
 var table:=b.kit.find_child("ProspectingTabletop",true,false)as MeshInstance3D
 var pan:=b.kit.find_child("GoldPan0",true,false)as MeshInstance3D
 check("pan base meets the independently drawn tabletop",absf(mesh_y(pan,false)-mesh_y(table,true))<.003)
 var pan_top: Vector3=(b.kit.find_child("PanInterior",true,false)as Node3D).global_position
 var nuggets: bool=true
 for i in 7:
  var nugget:=b.kit.find_child("Nugget%d"%i,true,false)as MeshInstance3D
  if nugget==null or absf(mesh_y(nugget,false)-pan_top.y)>.003:nuggets=false
 check("all seven pan nuggets actually rest in the pan",nuggets)
 var slate:=b.kit.find_child("OreSortingSlate",true,false)as MeshInstance3D
 var exterior: bool=true
 for i in 3:
  var nugget:=b.kit.find_child("ExteriorNugget%d"%i,true,false)as MeshInstance3D
  if nugget==null or absf(mesh_y(nugget,false)-mesh_y(slate,true))>.003:exterior=false
 check("exterior gold remnants rest on their sorting slate",exterior)
 var coins:=b.kit.get_node("BTCReserveCoinFaces")as MultiMeshInstance3D
 check("physical BTC reserve coins have eight stamped faces",coins.multimesh.instance_count==8 and (coins.material_override as StandardMaterial3D).albedo_texture.resource_path==b.BTC)
 var cv: PackedVector3Array=coins.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 check("BTC coin faces really face upward for the camera",(cv[1]-cv[0]).cross(cv[2]-cv[0]).dot(Vector3.UP)<0)
 var backed: bool=true
 for key in ["LiquiditySign","GMLogo","GoldmineWordmark","BTCEmblem","WantedRH","WantedJackHammer","BTCReserves"]:
  var image:=b.pictures[key]as MeshInstance3D
  var p: Vector3=image.global_position
  var hit=surface(floor_nodes,p+Vector3(.005,0,0),p-Vector3(.04,0,0))
  # BTC plaque uses its gold batch as backing, included among Fixed_*.
  if hit==null or absf(p.x-hit.x)>.012:backed=false
 check("paint and wanted paper meet actual physical backing surfaces",backed)
 var bracket:=b.kit.find_child("LanternBracket",true,false)as MeshInstance3D
 var chain:=b.kit.find_child("LanternChain",true,false)as MeshInstance3D
 check("oil lantern has a physical post bracket and supported chain",bracket!=null and chain!=null and mesh_y(chain,true)<=mesh_y(bracket,true)+.01)
 check("ordinary movement returns to the original lake route",walk(c,Vector3(-8,0,13)))
 check("water remains impassable after the optional cabin visit",c._collide(Vector3(25,0,20)).x<=-4)
 check("all ammunition, holdings and progression are unchanged",c.armory.snapshot()==inventory and c.get_beat()==c.Beat.ARRIVE and c.staging_count()==0)
 check("the original rigged Logan and working skiff remain present",c._logan.model.find_children("*","Skeleton3D",true,false)[0].get_bone_count()==65 and c._skiff.ready_art)
 print("LOGAN_CABIN: ",checks," checks, ",failures," failed")
 c.queue_free();await get_tree().process_frame;get_tree().quit(0 if failures==0 else 1)
