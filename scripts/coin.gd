class_name Coin
extends Area2D
## Collectible energy shard ("mesh shard").

var taken := false
var _t := 0.0
var _base_y := 0.0
var _glow: Polygon2D
var _core: Polygon2D

func _ready() -> void:
	add_to_group("shard")
	collision_layer = 0
	collision_mask = 2
	_t = randf() * TAU
	_base_y = position.y

	_glow = Polygon2D.new()
	_glow.color = Color(0.2, 0.83, 1.0, 0.16)
	_glow.polygon = _diamond(17.0)
	add_child(_glow)

	var mid := Polygon2D.new()
	mid.color = Color("#67e8f9")
	mid.polygon = _diamond(11.0)
	add_child(mid)

	_core = Polygon2D.new()
	_core.color = Color("#ecfdf5")
	_core.polygon = _diamond(4.5)
	add_child(_core)

	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 15.0
	cs.shape = sh
	add_child(cs)

	body_entered.connect(_on_body_entered)


static func _diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.62, 0), Vector2(0, r), Vector2(-r * 0.62, 0),
	])


func _process(delta: float) -> void:
	_t += delta
	rotation += delta * 2.4
	position.y = _base_y + sin(_t * 2.6) * 4.0
	var pulse := 1.0 + sin(_t * 4.0) * 0.12
	_glow.scale = Vector2(pulse, pulse)


func _on_body_entered(body: Node2D) -> void:
	if taken or not body is Player:
		return
	taken = true
	Globals.play_sfx("coin")
	_burst()
	_spawn_slash()
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl != null and lvl.has_method("on_coin_collected"):
		lvl.on_coin_collected()
	queue_free()


func _spawn_slash() -> void:
	SlashEffect.spawn(get_parent(), global_position,
			SlashEffect.SlashType.WATER, 0.035, Color(0.4, 0.9, 1.0, 0.7), 2.0)


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.45
	p.local_coords = false
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#a7f3d0"), Color(0.13, 0.98, 0.69, 0.0)])
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
