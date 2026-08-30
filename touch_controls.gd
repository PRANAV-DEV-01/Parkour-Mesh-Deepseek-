class_name TouchControls
extends CanvasLayer
## On-screen controls for touchscreen devices (Android / iOS).
## Uses TouchScreenButton so multi-touch works natively and the mapped
## actions (move_left, move_right, jump, dash) drive the exact same input
## path as the keyboard.

signal pause_pressed

const BTN_COLOR := Color(0.06, 0.10, 0.20, 0.42)
const BTN_BORDER := Color(0.22, 0.83, 0.93, 0.55)
const ICON_COLOR := Color(1, 1, 1, 0.82)
const ICON_COLOR_DIM := Color(1, 1, 1, 0.45)

var _buttons: Array[TouchScreenButton] = []

func _ready() -> void:
	layer = 20
	if not DisplayServer.is_touchscreen_available():
		visible = false
		set_process(false)
		return
	var vp := get_viewport().get_visible_rect().size

	_action_button("move_left", Vector2(130, vp.y - 120), 62, _arrow_points(-1))
	_action_button("move_right", Vector2(310, vp.y - 120), 62, _arrow_points(1))
	_action_button("jump", Vector2(vp.x - 125, vp.y - 135), 74, _up_arrow_points())
	_action_button("dash", Vector2(vp.x - 290, vp.y - 85), 54, _dash_icon_points())
	_pause_button(Vector2(vp.x - 56, 96))


func _action_button(action: String, pos: Vector2, radius: float,
		icon: PackedVector2Array) -> void:
	var b := TouchScreenButton.new()
	b.name = action.to_pascal_case()
	b.action = action
	b.position = pos
	var sh := CircleShape2D.new()
	sh.radius = radius
	b.shape = sh
	add_child(b)

	var disc := Polygon2D.new()
	disc.polygon = _circle_points(radius)
	disc.color = BTN_COLOR
	b.add_child(disc)

	var ring := Line2D.new()
	ring.points = _circle_points(radius)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = BTN_BORDER
	b.add_child(ring)

	var glyph := Polygon2D.new()
	glyph.polygon = icon
	glyph.color = ICON_COLOR
	b.add_child(glyph)

	b.pressed.connect(func() -> void:
		b.modulate = Color(1.35, 1.35, 1.35, 1.0))
	b.released.connect(func() -> void:
		b.modulate = Color.WHITE)
	_buttons.append(b)


func _pause_button(pos: Vector2) -> void:
	var b := TouchScreenButton.new()
	b.name = "Pause"
	b.position = pos
	var sh := CircleShape2D.new()
	sh.radius = 34.0
	b.shape = sh
	add_child(b)

	var disc := Polygon2D.new()
	disc.polygon = _circle_points(34.0)
	disc.color = BTN_COLOR
	b.add_child(disc)

	var ring := Line2D.new()
	ring.points = _circle_points(34.0)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = BTN_BORDER
	b.add_child(ring)

	var bar_l := Polygon2D.new()
	bar_l.polygon = PackedVector2Array([
		Vector2(-11, -13), Vector2(-3, -13), Vector2(-3, 13), Vector2(-11, 13)])
	bar_l.color = ICON_COLOR
	b.add_child(bar_l)
	var bar_r := Polygon2D.new()
	bar_r.polygon = PackedVector2Array([
		Vector2(3, -13), Vector2(11, -13), Vector2(11, 13), Vector2(3, 13)])
	bar_r.color = ICON_COLOR
	b.add_child(bar_r)

	b.pressed.connect(func() -> void: pause_pressed.emit())


# ---------------------------------------------------------------- geometry
static func _circle_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 30:
		var a := TAU * float(i) / 30.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


static func _arrow_points(dir: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(16 * dir, -20), Vector2(-14 * dir, 0), Vector2(16 * dir, 20)])


static func _up_arrow_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -22), Vector2(19, 0), Vector2(8, 0), Vector2(8, 20),
		Vector2(-8, 20), Vector2(-8, 0), Vector2(-19, 0)])


static func _chevron_points(offset: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		offset + Vector2(-7, -15), offset + Vector2(8, 0), offset + Vector2(-7, 15),
		offset + Vector2(-14, 12), offset + Vector2(-4, 0), offset + Vector2(-14, -12)])


static func _dash_icon_points() -> PackedVector2Array:
	var pts := _chevron_points(Vector2(-10, 0))
	pts.append_array(_chevron_points(Vector2(12, 0)))
	return pts
