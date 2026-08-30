extends Control
## Final results screen shown after beating every level.

const ACCENT := Color("#22d3ee")
const ACCENT_2 := Color("#e879f9")

func _ready() -> void:
	Globals.load_progress()
	add_child(BackgroundGrid.new())
	Globals.play_sfx("win", -2.0)
	_build()
	_add_win_decorations()


func _add_win_decorations() -> void:
	var deco := Node2D.new()
	deco.z_index = -3
	add_child(deco)
	MenuDecoration.add_icon(deco, Vector2(180, 200), "ultimate", 96, 0.3)
	MenuDecoration.add_icon(deco, Vector2(1100, 200), "ultimate", 96, 0.3)
	MenuDecoration.add_icon(deco, Vector2(180, 520), "fire", 72, 0.2)
	MenuDecoration.add_icon(deco, Vector2(1100, 520), "lightning", 72, 0.2)
	MenuDecoration.add_floating_particles(deco, Rect2(0, 0, 1280, 720), 35,
			Color(0.95, 0.85, 0.3, 0.6))


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var t1 := _label("YOU CONQUERED", 64, ACCENT)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t1)
	var t2 := _label("THE MESH!", 76, ACCENT_2)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t2)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.07, 0.14, 0.9)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	panel.add_child(stats)

	var run_time := _stat_line(stats, "TOTAL TIME", Globals.format_time(Globals.run_total_time))
	run_time.modulate = Color(1.15, 1.15, 1.15)
	_stat_line(stats, "SHARDS COLLECTED", str(Globals.run_total_coins))
	_stat_line(stats, "TOTAL DEATHS", str(Globals.run_total_deaths))

	if not Globals.best_times.is_empty():
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 8)
		stats.add_child(sp)
		for i in Globals.LEVELS.size():
			if Globals.best_times.has(i):
				_stat_line(stats, "BEST  LEVEL %d" % (i + 1), Globals.format_time(float(Globals.best_times[i])))

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 20)
	col.add_child(gap2)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_button(row, "PLAY AGAIN", func() -> void: Globals.start_game(0), true)
	_button(row, "MAIN MENU", func() -> void: Globals.to_main_menu(), false)


func _stat_line(parent: Node, key: String, value: String) -> Label:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 26)
	var k := _label(key, 21, Color(0.6, 0.72, 0.88))
	k.custom_minimum_size = Vector2(260, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(k)
	var v := _label(value, 21, Color.WHITE)
	v.custom_minimum_size = Vector2(160, 0)
	h.add_child(v)
	parent.add_child(h)
	return v


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(parent: Node, text: String, on_pressed: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(ACCENT if primary else Color("#141f36")))
	b.add_theme_stylebox_override("hover", _style(Color("#67e8f9") if primary else Color("#1c2c4c")))
	b.add_theme_stylebox_override("pressed", _style(Color("#22d3ee") if primary else Color("#101a30")))
	b.add_theme_stylebox_override("focus", _style(Color("#67e8f9") if primary else Color("#1c2c4c")))
	b.add_theme_color_override("font_color", Color("#0b1120") if primary else Color("#e2e8f0"))
	b.pressed.connect(func() -> void:
		Globals.play_sfx("click")
		on_pressed.call())
	parent.add_child(b)
	return b


func _style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
