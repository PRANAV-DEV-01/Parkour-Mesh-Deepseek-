class_name CrumblePlatform
extends StaticBody2D
## Fragile platform: shakes briefly when stepped on, falls away,
## then rebuilds itself a few seconds later.

@export var size := Vector2(150.0, 26.0)

var _shape: CollisionShape2D
var _sensor: Area2D
var _visual_root: Node2D
var _edge_line: Line2D
var _state := "idle"   # idle | shaking | gone
var _shake_t := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("accent")
	_visual_root = Node2D.new()
	add_child(_visual_root)
	var lines := Platform.add_platform_visuals(_visual_root, size)
	_edge_line = lines[0]
	_edge_line.default_color = Color("#f59e0b")

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	cs.name = "Shape"
	add_child(cs)
	_shape = cs

	# Sensor strip just above the surface.
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(size.x - 8.0, 14.0)
	acs.shape = ash
	acs.position = Vector2(0, -size.y / 2.0 - 6.0)
	area.add_child(acs)
	add_child(area)
	_sensor = area
	area.body_entered.connect(_on_stepped)


func _on_stepped(body: Node2D) -> void:
	if _state != "idle" or not body is Player:
		return
	_state = "shaking"
	_shake_t = 0.0
	Globals.play_sfx("crumble", -6.0)


func _process(delta: float) -> void:
	if _state == "shaking":
		_shake_t += delta
		_visual_root.position.x = randf_range(-2.5, 2.5)
		if _shake_t >= 0.45:
			_break_apart()


func _break_apart() -> void:
	_state = "gone"
	set_deferred("collision_layer", 0)
	_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual_root, "position:y", 46.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual_root, "modulate:a", 0.0, 0.5)
	get_tree().create_timer(2.6).timeout.connect(_try_respawn)


func _try_respawn() -> void:
	if not is_inside_tree():
		return
	if _player_nearby():
		get_tree().create_timer(0.5).timeout.connect(_try_respawn)
		return
	_state = "idle"
	collision_layer = 1
	_shape.set_deferred("disabled", false)
	_visual_root.position = Vector2.ZERO
	_visual_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_visual_root, "modulate:a", 1.0, 0.3)


## True if a player overlaps the platform's FULL volume (not just the top
## sensor strip) - prevents respawning inside a passing player and leaving
## ghost collision behind.
func _player_nearby() -> bool:
	var half := size * 0.5 + Vector2(20.0, 20.0)
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D and Rect2(global_position - half, half * 2.0).has_point(p.global_position):
			return true
	return false


func set_accent(c: Color) -> void:
	if _edge_line != null:
		_edge_line.default_color = Color("#f59e0b").lerp(c, 0.25)
