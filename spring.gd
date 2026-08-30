class_name SpringPad
extends Area2D
## Bounce pad that launches the player upward.

@export var strength := 1080.0

var _cooldown := 0.0
var _plate: Polygon2D
var _plate_glow: Line2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("accent")
	var w := 54.0

	var base := Polygon2D.new()
	base.color = Color("#1e293b")
	base.polygon = PackedVector2Array([
		Vector2(-w / 2.0, 10.0), Vector2(w / 2.0, 10.0),
		Vector2(w / 2.0 - 6.0, 18.0), Vector2(-w / 2.0 + 6.0, 18.0),
	])
	add_child(base)

	for i in 3:
		var coil := Line2D.new()
		var y := 4.0 + i * 3.5
		coil.width = 2.0
		coil.default_color = Color(0.7, 0.8, 0.95, 0.4)
		coil.points = PackedVector2Array([Vector2(-w / 2.0 + 8.0, y), Vector2(w / 2.0 - 8.0, y)])
		add_child(coil)

	_plate = Polygon2D.new()
	_plate.color = Color("#34d399")
	_plate.polygon = PackedVector2Array([
		Vector2(-w / 2.0, -4.0), Vector2(w / 2.0, -4.0),
		Vector2(w / 2.0 - 4.0, 5.0), Vector2(-w / 2.0 + 4.0, 5.0),
	])
	add_child(_plate)
	_plate_glow = Line2D.new()
	_plate_glow.width = 4.0
	_plate_glow.default_color = Color("#a7f3d0", 0.35)
	_plate_glow.points = PackedVector2Array([Vector2(-w / 2.0 + 3.0, -3.5), Vector2(w / 2.0 - 3.0, -3.5)])
	add_child(_plate_glow)

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, 26.0)
	cs.shape = sh
	cs.position = Vector2(0, -2.0)
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or _cooldown > 0.0:
		return
	_cooldown = 0.25
	body.bounce(strength)
	Globals.play_sfx("spring")
	SlashEffect.spawn(get_parent(), body.global_position,
			SlashEffect.SlashType.WIND, 0.05, Color(0.5, 1.0, 0.7, 0.7), 1.5)
	var tw := create_tween()
	_plate.scale.y = 0.45
	tw.tween_property(_plate, "scale:y", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_accent(c: Color) -> void:
	if _plate != null:
		_plate.color = c
