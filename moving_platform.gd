class_name MovingPlatform
extends AnimatableBody2D
## Platform that glides between its start position and start + move_offset.
## Movement runs inside _physics_process so sync_to_physics can report a
## correct constant velocity and CharacterBody2D riders are carried smoothly.

@export var size := Vector2(180.0, 28.0)
@export var move_offset := Vector2(320.0, 0.0)
@export var duration := 2.4
@export var start_delay := 0.0

var _lines: Array[Line2D]
var _origin := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	add_to_group("accent")

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)

	_lines = Platform.add_platform_visuals(self, size)
	_origin = position


func _physics_process(delta: float) -> void:
	_t += delta
	var hold := start_delay * 0.5
	var cycle := duration * 2.0 + hold + start_delay
	var lt := fposmod(_t - start_delay, cycle)
	var f := 0.0
	if lt < duration:
		f = _sine_ease(lt / duration)
	elif lt < duration + hold:
		f = 1.0
	elif lt < duration * 2.0 + hold:
		f = 1.0 - _sine_ease((lt - duration - hold) / duration)
	position = _origin + move_offset * f


static func _sine_ease(u: float) -> float:
	return (1.0 - cos(PI * clampf(u, 0.0, 1.0))) * 0.5


func set_accent(c: Color) -> void:
	if _lines.size() >= 2:
		_lines[0].default_color = c
		_lines[1].default_color = Color(c.r, c.g, c.b, 0.22)
