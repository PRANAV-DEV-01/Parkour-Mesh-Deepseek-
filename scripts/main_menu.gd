extends Control
## Main menu: title, play, level select, how-to-play and quit.

const ACCENT := Color("#22d3ee")
const ACCENT_2 := Color("#e879f9")

var _howto: Control
var _title_box: VBoxContainer
var _t := 0.0

func _ready() -> void:
	Globals.load_progress()
	add_child(BackgroundGrid.new())
	_build()
	_add_menu_decorations()
	var tw := create_tween().set_loops()
	tw.tween_property(_title_box, "position:y", 14.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title_box, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_menu_decorations() -> void:
	var deco := Node2D.new()
	deco.z_index = -3
	add_child(deco)
	MenuDecoration.add_icon(deco, Vector2(160, 180), "fire", 80, 0.25)
	MenuDecoration.add_icon(deco, Vector2(1120, 180), "lightning", 80, 0.25)
	MenuDecoration.add_icon(deco, Vector2(160, 520), "water", 64, 0.2)
	MenuDecoration.add_icon(deco, Vector2(1120, 520), "wind", 64, 0.2)
	MenuDecoration.add_icon(deco, Vector2(640, 620), "ultimate", 72, 0.15)
	MenuDecoration.add_floating_particles(deco, Rect2(0, 0, 1280, 720), 25,
			Color(0.3, 0.8, 1.0))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	_title_box = VBoxContainer.new()
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_title_box)

	var t1 := _label("PARKOUR", 92, ACCENT)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.add_theme_color_override("font_shadow_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	t1.add_theme_constant_override("shadow_offset_x", 0)
	t1.add_theme_constant_override("shadow_offset_y", 6)
	_title_box.add_child(t1)

	var t2 := _label("M E S H", 60, ACCENT_2)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t2)

	var sub := _label("a neon parkour adventure", 20, Color(0.62, 0.72, 0.88))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.85
	_title_box.add_child(sub)

	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap1)

	_menu_button(col, "PLAY", func() -> void: Globals.start_game(0), true)

	# Level select row.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for i in Globals.LEVELS.size():
		var locked: bool = i > Globals.unlocked_level
		var txt := "LEVEL %d" % (i + 1)
		if locked:
			txt += "  [LOCKED]"
		var idx := i
		var b := _small_button(row, txt, func() -> void: Globals.start_game(idx), locked)
		if i == Globals.unlocked_level:
			b.add_theme_color_override("font_color", Color("#facc15"))

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap2)

	_menu_button(col, "HOW TO PLAY", _show_howto, false)
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		_menu_button(col, "QUIT", func() -> void: get_tree().quit(), false)

	# Best time line.
	var best_line := "NO RECORDS YET - SET SOME!"
	if not Globals.best_times.is_empty():
		var parts: PackedStringArray = []
		var total := 0.0
		var all_done := true
		for i in Globals.LEVELS.size():
			if Globals.best_times.has(i):
				parts.append("L%d %s" % [i + 1, Globals.format_time(Globals.best_times[i])])
				total += float(Globals.best_times[i])
			else:
				all_done = false
		best_line = "BEST   " + "      ".join(parts)
		if all_done:
			best_line += "      TOTAL %s" % Globals.format_time(total)
	var best := _label(best_line, 16, Color(0.55, 0.66, 0.82))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.modulate.a = 0.9
	col.add_child(best)

	var ver := _label("v1.0  -  Godot 4", 13, Color(0.45, 0.52, 0.65, 0.7))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)

	_build_howto(root)


func _build_howto(parent: Control) -> void:
	_howto = Control.new()
	_howto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_howto.visible = false
	parent.add_child(_howto)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_howto.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_hide_howto())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_howto.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.07, 0.14, 0.98)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 28.0
	sb.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := _label("HOW TO PLAY", 38, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var touch := DisplayServer.is_touchscreen_available()
	var lines := []
	if touch:
		lines = [
			["MOVE", "left / right pads on the bottom-left"],
			["JUMP", "JUMP pad (tap again in mid-air for a double jump)"],
			["WALL JUMP", "slide down walls, then jump to kick off them"],
			["DASH", "DASH pad  -  quick horizontal burst, also mid-air"],
			["SPRINGS", "bounce pads launch you sky-high"],
			["GOAL", "grab shards, reach the portal"],
			["RESTART / PAUSE", "pause button on the top-right"],
		]
	else:
		lines = [
			["MOVE", "A / D  or  Arrow Keys"],
			["JUMP", "Space / W / Up   (press again in mid-air for a double jump)"],
			["WALL JUMP", "slide down walls, then jump to kick off them"],
			["DASH", "Shift / X  -  quick horizontal burst, also mid-air"],
			["SPRINGS", "bounce pads launch you sky-high"],
			["GOAL", "grab shards, reach the portal"],
			["RESTART / PAUSE", "R restarts the level, ESC pauses"],
		]
	for pair in lines:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		var k := _label(pair[0], 19, ACCENT_2)
		k.custom_minimum_size = Vector2(210, 0)
		h.add_child(k)
		var val := _label(pair[1], 19, Color("#dbeafe"))
		val.custom_minimum_size = Vector2(560, 0)
		h.add_child(val)
		v.add_child(h)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	v.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "GOT IT!"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_stylebox_override("normal", _btn_style(Color("#141f36"), ACCENT))
	close_btn.add_theme_stylebox_override("hover", _btn_style(Color("#1c2c4c"), ACCENT))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color("#101a30"), ACCENT))
	close_btn.add_theme_stylebox_override("focus", _btn_style(Color("#1c2c4c"), ACCENT))
	close_btn.pressed.connect(_hide_howto)
	var cc := CenterContainer.new()
	cc.add_child(close_btn)
	v.add_child(cc)


func _show_howto() -> void:
	_howto.visible = true


func _hide_howto() -> void:
	_howto.visible = false
	Globals.play_sfx("click")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _howto.visible:
		_hide_howto()


# ---------------------------------------------------------------- helpers
func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


func _menu_button(parent: Node, text: String, on_pressed: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26 if primary else 21)
	b.add_theme_color_override("font_color", Color("#0b1120") if primary else Color("#e2e8f0"))
	b.add_theme_color_override("font_hover_color", Color("#0b1120") if primary else Color.WHITE)
	var border := ACCENT if primary else Color(0.3, 0.42, 0.58, 0.8)
	b.add_theme_stylebox_override("normal", _btn_style(ACCENT if primary else Color("#141f36"), border))
	b.add_theme_stylebox_override("hover", _btn_style(Color("#67e8f9") if primary else Color("#1c2c4c"), ACCENT))
	b.add_theme_stylebox_override("pressed", _btn_style(Color("#22d3ee") if primary else Color("#101a30"), ACCENT))
	b.add_theme_stylebox_override("focus", _btn_style(Color("#67e8f9") if primary else Color("#1c2c4c"), ACCENT))
	b.pressed.connect(func() -> void:
		Globals.play_sfx("click")
		on_pressed.call())
	parent.add_child(b)
	return b


func _small_button(parent: Node, text: String, on_pressed: Callable, disabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", _btn_style(Color("#141f36"), Color(0.3, 0.42, 0.58, 0.8)))
	b.add_theme_stylebox_override("hover", _btn_style(Color("#1c2c4c"), ACCENT))
	b.add_theme_stylebox_override("pressed", _btn_style(Color("#101a30"), ACCENT))
	b.add_theme_stylebox_override("focus", _btn_style(Color("#1c2c4c"), ACCENT))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.07, 0.09, 0.15, 0.7), Color(0.18, 0.22, 0.3, 0.6)))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.46, 0.56, 0.7))
	if not disabled:
		b.pressed.connect(func() -> void:
			Globals.play_sfx("click")
			on_pressed.call())
	parent.add_child(b)
	return b
