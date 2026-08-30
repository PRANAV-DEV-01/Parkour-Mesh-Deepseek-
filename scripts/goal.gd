class_name GoalPortal
extends Area2D
## Level exit portal. Sucks the player in and signals the level.

signal reached

var done := false
var _phase := 0.0
var _ring_a: Array[float] = []
var _ring_b: Node2D
var _core: Polygon2D
var _sparkles: CPUParticles2D
var _color := Color("#22d3ee")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("accent")
	_phase = randf() * TAU

	_ring_b = Node2D.new()
	add_child(_ring_b)

	_core = Polygon2D.new()
	_core.color = Color(1, 1, 1, 0.85)
	_core.polygon = PackedVector2Array([
		Vector2(0, -9), Vector2(6, 0), Vector2(0, 9), Vector2(-6, 0),
	])
	add_child(_core)

	_sparkles = CPUParticles2D.new()
	_sparkles.amount = 22
	_sparkles.lifetime = 1.3
	_sparkles.local_coords = false
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = 30.0
	_sparkles.spread = 180.0
	_sparkles.gravity = Vector2.ZERO
	_sparkles.initial_velocity_min = 5.0
	_sparkles.initial_velocity_max = 25.0
	_sparkles.scale_amount_min = 1.5
	_sparkles.scale_amount_max = 3.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.4, 0.95, 1.0, 0.8), Color(0.4, 0.95, 1.0, 0.0)])
	_sparkles.color_ramp = g
	_sparkles.emitting = true
	add_child(_sparkles)

	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 34.0
	cs.shape = sh
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()
	var pulse := 1.0 + sin(_phase * 3.2) * 0.15
	_core.scale = Vector2(pulse, pulse)
	if _ring_b != null:
		_ring_b.rotation -= delta * 1.7


func _draw() -> void:
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 48, _color, 4.0)
	draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, 0.18), 8.0)
	# Rotating dashes on the inner ring.
	for i in 10:
		var a0 := _phase * 1.4 + TAU * float(i) / 10.0
		draw_arc(Vector2.ZERO, 24.0, a0, a0 + 0.38, 10, Color("#f472b6"), 3.0)


func _on_body_entered(body: Node2D) -> void:
	if done or not body is Player:
		return
	done = true
	Globals.play_sfx("goal")
	_spawn_goal_slash()
	var player := body as Player
	player.active = false
	player.velocity = Vector2.ZERO
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "scale", Vector2(0.05, 0.05), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "global_position", global_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	reached.emit()
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl != null and lvl.has_method("on_goal_reached"):
		lvl.on_goal_reached()


func _spawn_goal_slash() -> void:
	SlashEffect.spawn(get_parent(), global_position,
			SlashEffect.SlashType.ULTIMATE, 0.12, Color(1, 1, 1, 0.9), 0.7)


func set_accent(c: Color) -> void:
	_color = c
