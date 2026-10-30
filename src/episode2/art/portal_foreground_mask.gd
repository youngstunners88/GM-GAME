extends RefCounted
## A gun-only alpha view. Distance cannot distinguish the rifle from nearby
## walls or Inferno; protecting everything within1.6m exposed the old room.
var viewport: SubViewport
var camera: Camera3D
var layer: int=0

func attach(parent: Node3D,source: Camera3D) -> Texture2D:
	if not is_instance_valid(viewport):
		var used: int=0
		for node in source.get_tree().root.find_children("*","VisualInstance3D",true,false):used|=node.layers
		for i in range(19,0,-1):
			if (used&(1<<i))==0:
				layer=1<<i
				break
		assert(layer!=0,"A portal foreground mask needs one unused render layer")
		viewport=SubViewport.new()
		viewport.name="DoorwayWeaponMask"
		viewport.transparent_bg=true
		viewport.positional_shadow_atlas_size=0
		parent.add_child(viewport)
		camera=Camera3D.new()
		camera.cull_mask=layer
		var env:=Environment.new()
		env.background_mode=Environment.BG_CLEAR_COLOR
		camera.environment=env
		viewport.add_child(camera)
		camera.current=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	update(source)
	return viewport.get_texture()

func update(source: Camera3D) -> void:
	if not is_instance_valid(viewport):return
	if viewport.world_3d!=source.get_world_3d():viewport.world_3d=source.get_world_3d()
	viewport.size=Vector2i(source.get_viewport().get_visible_rect().size)
	viewport.msaa_3d=source.get_viewport().msaa_3d
	for node in source.find_children("*","VisualInstance3D",true,false):node.layers|=layer
	camera.global_transform=source.global_transform
	camera.fov=source.fov
	camera.near=source.near
	camera.far=source.far
	camera.keep_aspect=source.keep_aspect

func detach() -> void:
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
