<!-- dispatched: deepseek/deepseek-v3.2
     prompt: prompts/deepseek-structural-damage.md
     files inlined: 0
     tokens: 710 in / 2844 out
     cost: $0.0013
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
```gdscript
# destructible.gd
extends Node2D
class_name Destructible

signal wrecked
signal damage_stage_changed(stage: int)

@export_range(10, 1000, 1) var max_integrity: float = 100.0
@export var damage_stage: int = 0:
	set(value):
		if damage_stage != value:
			damage_stage = value
			damage_stage_changed.emit(damage_stage)
			queue_redraw()
			_apply_stage_effects()

@export var crack_color: Color = Color(0.2, 0.2, 0.2, 0.7)
@export var crack_width: float = 2.0
@export var debris_particles_scene: PackedScene

var current_integrity: float = max_integrity
var cracks: Array[PackedVector2Array] = []
var is_wrecked: bool = false
var original_parent: Node2D
var debris_timer: Timer

func _ready() -> void:
	original_parent = get_parent()
	current_integrity = max_integrity
	damage_stage = 0
	is_wrecked = false
	
	# Generate initial cracks
	_generate_cracks()
	
	# Setup debris timer
	debris_timer = Timer.new()
	debris_timer.wait_time = 0.05
	debris_timer.one_shot = true
	debris_timer.timeout.connect(_spawn_debris_burst)
	add_child(debris_timer)

func take_structural_damage(amount: float, is_heavy: bool = false) -> void:
	if is_wrecked:
		return
	
	if is_heavy:
		amount *= 1.5
	
	current_integrity = max(current_integrity - amount, 0.0)
	
	# Update damage stage based on integrity percentage
	var integrity_percent: float = current_integrity / max_integrity
	
	if integrity_percent <= 0.0:
		damage_stage = 3
		_wreck()
	elif integrity_percent <= 0.33:
		damage_stage = 2
	elif integrity_percent <= 0.66:
		damage_stage = 1
	else:
		damage_stage = 0
	
	# Spawn some debris
	if debris_timer and not debris_timer.is_stopped():
		debris_timer.start()

func _generate_cracks() -> void:
	cracks.clear()
	var rect: Rect2 = _get_parent_rect()
	
	# Generate 2-4 cracks per stage
	for i in range(4):
		var crack: PackedVector2Array = PackedVector2Array()
		var start_x: float = randf_range(rect.position.x, rect.end.x)
		var start_y: float = randf_range(rect.position.y, rect.end.y)
		
		crack.append(Vector2(start_x, start_y))
		
		# Create jagged crack path
		var segments: int = randi_range(3, 6)
		var current_pos: Vector2 = Vector2(start_x, start_y)
		
		for j in range(segments):
			var angle: float = randf_range(-PI/4, PI/4)
			var length: float = randf_range(rect.size.x * 0.2, rect.size.x * 0.4)
			var next_pos: Vector2 = current_pos + Vector2(cos(angle), sin(angle)) * length
			
			# Keep within bounds
			next_pos.x = clamp(next_pos.x, rect.position.x, rect.end.x)
			next_pos.y = clamp(next_pos.y, rect.position.y, rect.end.y)
			
			crack.append(next_pos)
			current_pos = next_pos
		
		cracks.append(crack)

func _get_parent_rect() -> Rect2:
	var parent_node: Node2D = get_parent()
	
	if parent_node is ColorRect:
		return Rect2(Vector2.ZERO, parent_node.size)
	elif parent_node.has_method("get_rect"):
		return parent_node.get_rect()
	
	# Fallback for StaticBody2D with CollisionShape2D
	for child in parent_node.get_children():
		if child is CollisionShape2D:
			var shape: Shape2D = child.shape
			if shape is RectangleShape2D:
				var extents: Vector2 = shape.size / 2.0
				return Rect2(-extents, shape.size)
	
	return Rect2(Vector2(-16, -16), Vector2(32, 32))

func _draw() -> void:
	if cracks.is_empty() or damage_stage == 0:
		return
	
	# Draw cracks for current and previous stages
	for stage in range(damage_stage + 1):
		if stage >= cracks.size():
			continue
		
		var alpha_mult: float = 0.3 + (stage * 0.2)
		var stage_color: Color = crack_color
		stage_color.a = crack_color.a * alpha_mult
		
		draw_polyline(cracks[stage], stage_color, crack_width * (1.0 + stage * 0.3), true)
		
		# Add crack endpoints
		if cracks[stage].size() > 0:
			draw_circle(cracks[stage][0], crack_width * 0.8, stage_color)
			draw_circle(cracks[stage][-1], crack_width * 0.8, stage_color)

func _apply_stage_effects() -> void:
	var parent: Node2D = get_parent()
	
	if not parent:
		return
	
	# Apply visual effects based on stage
	match damage_stage:
		1:
			# Slight desaturation and small tilt
			parent.modulate = parent.modulate.lerp(Color(0.9, 0.9, 0.9), 0.2)
			parent.rotation = randf_range(-0.02, 0.02)
		2:
			# More desaturation and noticeable tilt
			parent.modulate = parent.modulate.lerp(Color(0.7, 0.7, 0.7), 0.4)
			parent.rotation = randf_range(-0.05, 0.05)
			# Random offset
			parent.position += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		3:
			# Heavy desaturation and significant damage appearance
			parent.modulate = parent.modulate.lerp(Color(0.5, 0.5, 0.5), 0.6)
			parent.rotation = randf_range(-0.1, 0.1)

func _wreck() -> void:
	if is_wrecked:
		return
	
	is_wrecked = true
	var parent: Node2D = get_parent()
	
	# Handle specific prop types
	if parent is StaticBody2D:
		_handle_staticbody_wreck(parent)
	elif parent.has_node("PlatformEffector2D"):
		_handle_platform_wreck(parent)
	
	# Final visual state
	parent.modulate = Color(0.4, 0.4, 0.4)
	parent.rotation = randf_range(-0.15, 0.15)
	
	# Spawn final debris burst
	_spawn_debris_burst(20)
	
	wrecked.emit()

func _handle_staticbody_wreck(body: StaticBody2D) -> void:
	# For ladders: disable collision but keep node for reference
	if body.collision_layer & 4:  # Assuming layer 3 is ladder layer
		body.collision_layer = 0
		body.collision_mask = 0
		
		# If player is climbing, gently push them off
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for player in players:
			if player.has_method("get_climbing_on") and player.get_climbing_on() == body:
				player.call_deferred("force_stop_climbing")
	else:
		# Regular static body - just disable
		body.collision_layer = 0
		body.collision_mask = 0

func _handle_platform_wreck(platform: Node2D) -> void:
	var effector: PlatformEffector2D = platform.get_node("PlatformEffector2D")
	if effector:
		effector.collision_mask = 0
	
	# Check if any player is standing on this platform
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_on_floor():
			var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
			query.from = player.global_position
			query.to = player.global_position + Vector2.DOWN * 64
			query.exclude = [player]
			
			var result: Dictionary = space_state.intersect_ray(query)
			if result and result.collider == platform:
				# Give player a small upward boost to prevent falling through
				if player.has_method("apply_impulse"):
					player.call_deferred("apply_impulse", Vector2(0, -100))

func _spawn_debris_burst(count: int = 8) -> void:
	if not debris_particles_scene:
		return
	
	var rect: Rect2 = _get_parent_rect()
	var parent_pos: Vector2 = get_parent().global_position
	
	for i in range(count):
		var debris: GPUParticles2D = debris_particles_scene.instantiate()
		get_tree().current_scene.add_child(debris)
		
		var offset_x: float = randf_range(rect.position.x, rect.end.x)
		var offset_y: float = randf_range(rect.position.y, rect.end.y)
		debris.global_position = parent_pos + Vector2(offset_x, offset_y)
		
		# Set debris color to match parent
		debris.modulate = get_parent().modulate
		
		# Auto-remove after particles finish
		debris.finished.connect(debris.queue_free)

func repair() -> void:
	current_integrity = max_integrity
	damage_stage = 0
	is_wrecked = false
	
	var parent: Node2D = get_parent()
	parent.modulate = Color.WHITE
	parent.rotation = 0
	
	if parent is StaticBody2D:
		parent.collision_layer = 1
		parent.collision_mask = 1
	elif parent.has_node("PlatformEffector2D"):
		var effector: PlatformEffector2D = parent.get_node("PlatformEffector2D")
		if effector:
			effector.collision_mask = 1
	
	queue_redraw()
```

```gdscript
# Axe projectile modification (add to existing _impact() in src/combat/axe.gd)
func _impact() -> void:
	# Existing impact code...
	
	# NEW: Apply structural damage to destructible props
	var overlapping_bodies: Array[Node] = get_overlapping_bodies()
	
	for body in overlapping_bodies:
		var destructible: Destructible = body.get_node("Destructible")
		if destructible:
			var damage_amount: float = 25.0
			if big:  # big flag already exists on the axe
				damage_amount = 40.0
			
			destructible.take_structural_damage(damage_amount, big)
	
	# Continue with existing impact handling...
```

**Stage Thresholds:**
- Stage 0: 100%-66% integrity - No visible damage
- Stage 1: 66%-33% integrity - Light cracks, slight desaturation, minor tilt
- Stage 2: 33%-1% integrity - More cracks, noticeable desaturation, visible tilt, offset
- Stage 3: 0% integrity - Heavy cracks, significant desaturation, major tilt, collision disabled

**Wrecked Behavior:**
1. **Ladders**: Collision disabled immediately. Any climbing player receives `force_stop_climbing()` call to prevent soft-lock.
2. **One-way Platforms**: Platform effector disabled. Players standing on it get a small upward impulse to prevent falling through before they can react.

**Required Player Methods (must exist in player.gd):**
```gdscript
func get_climbing_on() -> StaticBody2D:
	# Should return the ladder currently being climbed or null
	pass

func force_stop_climbing() -> void:
	# Safely detach from ladder without falling animation lock
	pass

func apply_impulse(impulse: Vector2) -> void:
	# Apply immediate velocity change
	pass
```