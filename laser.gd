class_name LaserBeam
extends Area2D
## Rotating neon laser sweeping out from an emitter hub. Deadly along the
## whole beam; rotates forever at speed_rad radians/second.

@export var length := 240.0
@export var speed_rad := 1.5
@export var start_angle := -PI * 0.5

var _beam: Line2D
var _beam_glow: Line2D
var _color := Color("#fb7185")
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	rotation = start_angle
	add_to_group("accent")

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(length, 10.0)
	cs.shape = sh
	cs.position = Vector2(length * 0.5, 0)
	add_child(cs)

	_beam_glow = Line2D.new()
	_beam_glow.width = 12.0
	_beam_glow.default_color = Color(_color.r, _color.g, _color.b, 0.16)
	_beam_glow.points = PackedVector2Array([Vector2(6, 0), Vector2(length, 0)])
	add_child(_beam_glow)

	_beam = Line2D.new()
	_beam.width = 4.0
	_beam.default_color = _color
	_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.points = PackedVector2Array([Vector2(6, 0), Vector2(length, 0)])
	add_child(_beam)

	var hub := Polygon2D.new()
	hub.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)])
	hub.color = Color("#1b2440")
	add_child(hub)

	var hub_ring := Line2D.new()
	hub_ring.width = 3.0
	hub_ring.closed = true
	hub_ring.default_color = Color(0.55, 0.65, 0.85, 0.9)
	hub_ring.points = hub.polygon
	add_child(hub_ring)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	rotation += speed_rad * delta
	var flicker := 0.82 + 0.18 * sin(_t * 30.0)
	if _beam != null:
		_beam.default_color = Color(_color.r, _color.g, _color.b, flicker)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body._is_dead and body._spawn_shield <= 0.0:
		Globals.play_sfx("death", -4.0)
		body.die()


func set_accent(c: Color) -> void:
	# Lasers stay hostile-red regardless of level accent (readability).
	pass
