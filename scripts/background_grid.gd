class_name BackgroundGrid
extends CanvasLayer
## Animated parallax neon-grid background drawn procedurally (no assets needed).

@export var line_color := Color(0.16, 0.62, 0.78, 0.09)
@export var strong_line_color := Color(0.16, 0.62, 0.78, 0.16)
@export var dot_color := Color(0.13, 0.83, 0.93, 0.30)
@export var star_color := Color(0.55, 0.85, 1.0, 0.5)
@export var cell := 96.0
@export var parallax := 0.32

var _ctrl: Control

func _init() -> void:
	layer = -10

func _ready() -> void:
	_ctrl = Control.new()
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctrl.draw.connect(_on_draw)
	add_child(_ctrl)

func _process(_delta: float) -> void:
	if _ctrl != null:
		_ctrl.queue_redraw()

func _on_draw() -> void:
	var vp := _ctrl.get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var origin := Vector2.ZERO
	if cam != null:
		origin = cam.get_screen_center_position()
	var off := origin * parallax
	var now := Time.get_ticks_msec() / 1000.0

	var x0 := -fposmod(off.x, cell)
	var xx := x0
	while xx <= vp.x + cell:
		var col := line_color
		if fmod(round((xx + off.x) / cell), 4.0) == 0.0:
			col = strong_line_color
		_ctrl.draw_line(Vector2(xx, 0), Vector2(xx, vp.y), col, 1.0)
		xx += cell
	var yy := -fposmod(off.y, cell)
	while yy <= vp.y + cell:
		var col := line_color
		if fmod(round((yy + off.y) / cell), 4.0) == 0.0:
			col = strong_line_color
		_ctrl.draw_line(Vector2(0, yy), Vector2(vp.x, yy), col, 1.0)
		yy += cell

	# Glowing dots where major grid lines cross.
	var step := cell * 4.0
	var gx := -fposmod(off.x, step)
	while gx <= vp.x + step:
		var gy := -fposmod(off.y, step)
		while gy <= vp.y + step:
			var pulse := 0.65 + 0.35 * sin(now * 2.0 + (gx + gy) * 0.02)
			_ctrl.draw_circle(Vector2(gx, gy), 2.2 * pulse, dot_color)
			gy += step
		gx += step

	# Deterministic twinkling stars on a coarse lattice.
	var scell := 220.0
	var sx := -fposmod(off.x * 0.6, scell)
	var ix := int(floor((off.x * 0.6) / scell))
	while sx <= vp.x + scell:
		var sy := -fposmod(off.y * 0.6, scell)
		var iy := int(floor((off.y * 0.6) / scell))
		while sy <= vp.y + scell:
			var h := absi(hash(Vector2i(ix, iy)))
			if h % 3 == 0:
				var tw := 0.5 + 0.5 * sin(now * (1.0 + float(h % 7) * 0.23) + float(h % 11))
				var c := star_color
				c.a *= 0.25 + 0.75 * tw
				_ctrl.draw_circle(Vector2(sx, sy), 1.0 + float(h % 4) * 0.6, c)
			sy += scell
			iy += 1
		sx += scell
		ix += 1
