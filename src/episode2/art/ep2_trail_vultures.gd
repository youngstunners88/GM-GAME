extends Node3D
## Five distant turkey vultures: long fingered wings, small bare heads and banked thermals.
var birds: Array[Node3D] = []
var phase := 0.0
func _ready() -> void:
 var feather := StandardMaterial3D.new();feather.albedo_color=Color(.09,.075,.06);feather.cull_mode=BaseMaterial3D.CULL_DISABLED
 for i in 5:
  var bird := Node3D.new();add_child(bird);birds.append(bird)
  var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  for side in [-1.0,1.0]:
   for tri in [[Vector3(0,0,-.25),Vector3(side*1.1,.08,.1),Vector3(side*.65,0,.42)],[Vector3(0,0,-.25),Vector3(side*.65,0,.42),Vector3(0,0,.32)]]:
    for v in tri:mesh.surface_add_vertex(v)
   for j in 5:
    for v in [Vector3(side*.8,0,.14+j*.047),Vector3(side*(1.25-j*.055),0,.3+j*.085),Vector3(side*.7,0,.19+j*.047)]:mesh.surface_add_vertex(v)
  mesh.surface_end()
  var wing := MeshInstance3D.new();wing.mesh=mesh;wing.material_override=feather;bird.add_child(wing)
  var body := MeshInstance3D.new();var ball := SphereMesh.new();ball.radius=.13;ball.height=.6;body.mesh=ball;body.rotation.x=PI*.5;body.material_override=feather;bird.add_child(body)
  var head := MeshInstance3D.new();var h := SphereMesh.new();h.radius=.065;h.height=.15;head.mesh=h;head.position=Vector3(0,0,-.34)
  var red := StandardMaterial3D.new();red.albedo_color=Color(.32,.11,.08);head.material_override=red;bird.add_child(head)
func _process(delta: float) -> void:
 phase+=delta*.13
 for i in birds.size():
  var a: float = phase+i*TAU/5.0
  birds[i].position=Vector3(cos(a)*(14+i),26+i*2+sin(a*.7),sin(a)*(14+i))
  birds[i].rotation=Vector3(.03*sin(phase*4+i),PI-a, .22+.08*sin(a))
