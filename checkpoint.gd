class_name Checkpoint
extends Area2D
## Flag checkpoint; updates the level's respawn point when touched.

signal activated(cp: Checkpoint)

var is_active := false
var _flag: Polygon2D
var _pole: Line2D
var _glow_dot: Polygon2D
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_t = randf() * TAU

	_pole = Line2D.new()
	_pole.width = 4.0
	_pole.default_color = Color("#94a3b8")
	_pole.points = PackedVector2Array([Vector2(0, 24.0), Vector2(0, -40.0)])
	add_child(_pole)

	var base := Polygon2D.new()
	base.color = Color("#334155")
	base.polygon = PackedVector2Array([
		Vector2(-10.0, 24.0), Vector2(10.0, 24.0), Vector2(0.0, 14.0),
	])
	add_child(base)

	_flag = Polygon2D.new()
	_flag.color = Color("#64748b")
	_flag.position = Vector2.ZERO
	_flag.polygon = PackedVector2Array([
		Vector2(1.0, -40.0), Vector2(24.0, -33.0), Vector2(1.0, -25.0),
	])
	add_child(_flag)

	_glow_dot = Polygon2D.new()
	_glow_dot.color = Color(0.15, 0.23, 0.42)
	_glow_dot.polygon = PackedVector2Array([
		Vector2(0, -46), Vector2(4, -50), Vector2(0, -54), Vector2(-4, -50),
	])
	add_child(_glow_dot)

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(56.0, 90.0)
	cs.shape = sh
	cs.position = Vector2(0, -12.0)
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if is_active:
		_flag.rotation = sin(_t * 5.0) * 0.12


func _on_body_entered(body: Node2D) -> void:
	if is_active or not body is Player:
		return
	is_active = true
	Globals.play_sfx("checkpoint")
	_flag.color = Color("#34d399")
	_glow_dot.color = Color("#a7f3d0")
	var tw := create_tween()
	_flag.scale = Vector2(1.5, 1.5)
	tw.tween_property(_flag, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	activated.emit(self)
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl != null and lvl.has_method("register_checkpoint"):
		lvl.register_checkpoint(self)


func deactivate() -> void:
	is_active = false
	_flag.color = Color("#64748b")
	_glow_dot.color = Color(0.15, 0.23, 0.42)


func spawn_position() -> Vector2:
	return global_position + Vector2(0.0, -30.0)
