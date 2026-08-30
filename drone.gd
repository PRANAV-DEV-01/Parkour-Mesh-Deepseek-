class_name Drone
extends Area2D
## Patrolling sentinel drone. Glides between its start position and
## start + patrol_offset, killing the player on contact.

@export var patrol_offset := Vector2(180, 0)
@export var duration := 2.4
@export var eye_color := Color("#f472b6")

var _origin := Vector2.ZERO
var _t := 0.0
var _rotor: Line2D
var _eye: Polygon2D
var _eye_glow: Polygon2D
var _body_poly: Polygon2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("accent")
	_origin = position
	_t = randf() * TAU * 0.25

	_body_poly = Polygon2D.new()
	_body_poly.polygon = PackedVector2Array([
		Vector2(-16, -10), Vector2(16, -10), Vector2(24, 0),
		Vector2(16, 12), Vector2(-16, 12), Vector2(-24, 0),
	])
	_body_poly.color = Color("#1b2440")
	add_child(_body_poly)

	var trim := Line2D.new()
	trim.width = 2.5
	trim.default_color = Color(0.55, 0.65, 0.85, 0.9)
	trim.closed = true
	trim.points = _body_poly.polygon
	add_child(trim)

	_rotor = Line2D.new()
	_rotor.width = 3.0
	_rotor.default_color = Color(0.7, 0.8, 0.95, 0.55)
	_rotor.points = PackedVector2Array([Vector2(-22, -14), Vector2(22, -14)])
	add_child(_rotor)

	_eye_glow = Polygon2D.new()
	_eye_glow.polygon = _diamond(Vector2.ZERO, 13.0)
	_eye_glow.position = Vector2(0, -1)
	_eye_glow.color = Color(eye_color.r, eye_color.g, eye_color.b, 0.3)
	add_child(_eye_glow)

	_eye = Polygon2D.new()
	_eye.polygon = _diamond(Vector2.ZERO, 5.5)
	_eye.position = Vector2(0, -1)
	_eye.color = eye_color
	add_child(_eye)

	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 24.0
	cs.shape = sh
	cs.position = Vector2(0, -1)
	add_child(cs)

	body_entered.connect(_on_body_entered)


static func _diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.62, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.62, 0),
	])


func _physics_process(delta: float) -> void:
	_t += delta
	var f := (1.0 - cos(PI * clampf(fposmod(_t / maxf(duration, 0.01), 1.0), 0.0, 1.0))) * 0.5
	position = _origin + patrol_offset * f


func _process(delta: float) -> void:
	# Rotor spin + hover bob + scanning eye (visuals only; the collision
	# body follows the physics-driven patrol path).
	_rotor.rotation += delta * 18.0
	var bob := sin(_t * 5.0) * 2.0
	_body_poly.position.y = bob
	_eye.position.y = -1 + bob
	_eye_glow.position.y = -1 + bob
	var pulse := 1.0 + sin(_t * 7.0) * 0.18
	_eye.scale = Vector2(pulse, pulse)
	_eye_glow.scale = Vector2(pulse, pulse)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body._is_dead and body._spawn_shield <= 0.0:
		Globals.play_sfx("death", -4.0)
		body.die()


func set_accent(c: Color) -> void:
	eye_color = c
	if _eye != null:
		_eye.color = c
		_eye_glow.color = Color(c.r, c.g, c.b, 0.3)
