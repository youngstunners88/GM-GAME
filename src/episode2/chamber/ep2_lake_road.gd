class_name Ep2LakeRoad
extends RefCounted
## The same surveyed road is visible at the ranch, during mounting and on the ride.
const ORIGIN := Vector3(-13,0,1230)
const POINTS: Array = [
	Vector2(0,0),Vector2(10,-9),Vector2(21,-9),Vector2(33,-10),
	Vector2(49,-48),Vector2(70,-82),Vector2(102,-119),Vector2(124,-160),
	Vector2(164,-193),Vector2(202,-222),Vector2(233,-262),Vector2(260,-300),
	Vector2(290,-338),Vector2(320,-374)]
const RETURN_POINTS := [Vector3(21,0,-6),Vector3(21,0,30),Vector3(13,0,70),Vector3(13,0,145)]

static func smooth(points: Array,spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in points.size()-1:
		var p0: Vector2=points[maxi(i-1,0)]
		var p1: Vector2=points[i]
		var p2: Vector2=points[i+1]
		var p3: Vector2=points[mini(i+2,points.size()-1)]
		var steps: int=maxi(4,int(p1.distance_to(p2)/spacing))
		for k in steps:
			var t: float=float(k)/steps
			var t2: float=t*t
			var t3: float=t2*t
			var p: Vector2=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3)
			out.append(Vector3(p.x,0,p.y))
	var last: Vector2=points[-1]
	out.append(Vector3(last.x,0,last.y))
	return out

static func build(parent: Node3D,origin: Vector3=Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name="LakeRoadSurvey"
	root.position=origin
	parent.add_child(root)
	var mat := ShaderMaterial.new()
	mat.shader=load("res://src/episode2/art/lake_road.gdshader")
	mat.set_shader_parameter("sand_tex",load("res://src/episode2/assets/town/tex_desert.jpg"))
	mat.set_shader_parameter("gravel_tex",load("res://src/episode2/assets/textures/tex_gravel.jpg"))
	var points: PackedVector3Array=smooth(POINTS,1.5)
	var arc: Array[float]=[0.0]
	for i in range(1,points.size()):arc.append(arc[-1]+points[i].distance_to(points[i-1]))
	var visible_points := PackedVector3Array()
	for i in points.size():
		if arc[i]<=arc[-1]-82:visible_points.append(points[i])
	ribbon(root,visible_points,5.8,mat,.022).name="LakeTrail"
	ribbon(root,PackedVector3Array(RETURN_POINTS),5.8,mat,.022).name="TownReturnRoad"
	return root

static func ribbon(parent: Node3D,points: PackedVector3Array,width: float,mat: Material,y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in points.size():
		var tangent: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		tangent.y=0
		tangent=tangent.normalized() if tangent.length()>.001 else Vector3.FORWARD
		var side := Vector3(tangent.z,0,-tangent.x)*(width*.5)
		left.append(points[i]-side+Vector3(0,y,0))
		right.append(points[i]+side+Vector3(0,y,0))
	for i in points.size()-1:
		var v0: float=float(i)/maxf(1,points.size()-1)
		var v1: float=float(i+1)/maxf(1,points.size()-1)
		for row in [[left[i],Vector2(0,v0)],[right[i],Vector2(1,v0)],[left[i+1],Vector2(0,v1)],
			[right[i],Vector2(1,v0)],[right[i+1],Vector2(1,v1)],[left[i+1],Vector2(0,v1)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(row[1])
			st.add_vertex(row[0])
	var mesh := MeshInstance3D.new()
	mesh.mesh=st.commit()
	mesh.material_override=mat
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
