class_name GameHUD
extends CanvasLayer
## In-game UI: shard/death counters, timer, dash gauge, toast,
## fade transitions, pause menu and level-complete overlay.

signal restart_requested
signal next_level_requested
signal menu_requested

var timing := true

var _player: Player
var _elapsed := 0.0
var _coin_count := 0
var _coin_total := 0
var _death_count := 0

var _accent := Color("#22d3ee")

var _time_label: Label
var _coins_label: Label
var _deaths_label: Label
var _toast_label: Label
var _hint_label: Label
var _combo_label: Label
var _fade: ColorRect
var _pause_overlay: Control
var _complete_overlay: Control
var _dash_fill: ColorRect
var _resume_btn: Button
var _next_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build()
	if DisplayServer.is_touchscreen_available():
		_hint_label.visible = false


# ------------------------------------------------------------------ build
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := HBoxContainer.new()
	top_left.position = Vector2(20, 14)
	top_left.add_theme_constant_override("separation", 26)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)

	_coins_label = _stat_chip(top_left, Color("#34d399"))
	_deaths_label = _stat_chip(top_left, Color("#fb7185"))

	_time_label = _make_label("00:00.0", 30, Color("#e2e8f0"))
	_time_label.anchor_left = 1.0
	_time_label.anchor_right = 1.0
	_time_label.offset_left = -220.0
	_time_label.offset_right = -20.0
	_time_label.offset_top = 14.0
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_time_label)

	_hint_label = _make_label("ESC  Pause      R  Restart", 15, Color(0.7, 0.78, 0.92, 0.55))
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_top = -34.0
	_hint_label.offset_bottom = -10.0
	root.add_child(_hint_label)

	var dash_box := VBoxContainer.new()
	dash_box.position = Vector2(20, 64)
	dash_box.add_theme_constant_override("separation", 4)
	dash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dash_box)
	var dash_title := _make_label("DASH", 13, Color(0.65, 0.75, 0.9, 0.6))
	dash_box.add_child(dash_title)
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(110, 10)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0.08, 0.12, 0.22, 0.85)
	sbg.corner_radius_top_left = 5
	sbg.corner_radius_top_right = 5
	sbg.corner_radius_bottom_left = 5
	sbg.corner_radius_bottom_right = 5
	bar_bg.add_theme_stylebox_override("panel", sbg)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_box.add_child(bar_bg)
	_dash_fill = ColorRect.new()
	_dash_fill.color = Color("#38bdf8")
	_dash_fill.size = Vector2(106, 6)
	_dash_fill.position = Vector2(2, 2)
	_dash_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_dash_fill)

	_toast_label = _make_label("", 40, Color.WHITE)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = 90.0
	_toast_label.offset_bottom = 150.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast_label)

	_combo_label = _make_label("", 26, Color("#fde68a"))
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.anchor_right = 1.0
	_combo_label.offset_top = 52.0
	_combo_label.offset_bottom = 90.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_combo_label.add_theme_constant_override("shadow_offset_y", 2)
	_combo_label.modulate.a = 0.0
	root.add_child(_combo_label)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_pause_overlay = _overlay_base(root)
	var pv := _panel_into(_pause_overlay)
	pv.add_child(_make_title("PAUSED", 46))
	_resume_btn = _menu_button(pv, "RESUME", _on_resume)
	_menu_button(pv, "RESTART LEVEL", func() -> void: restart_requested.emit())
	_menu_button(pv, "MAIN MENU", func() -> void: menu_requested.emit())

	_complete_overlay = _overlay_base(root)
	var cv := _panel_into(_complete_overlay)
	cv.add_child(_make_title("LEVEL COMPLETE!", 42))
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(stats)
	_complete_stats_node = stats
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	cv.add_child(spacer)
	_next_btn = _menu_button(cv, "NEXT LEVEL", func() -> void: next_level_requested.emit())
	_menu_button(cv, "RETRY", func() -> void: restart_requested.emit())
	_menu_button(cv, "MAIN MENU", func() -> void: menu_requested.emit())


var _complete_stats_node: VBoxContainer


func _stat_chip(parent: Control, color: Color) -> Label:
	var l := _make_label("", 30, color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _make_label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_title(text: String, size_px: int) -> Label:
	var l := _make_label(text, size_px, _accent)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _menu_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 0)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color("#e2e8f0"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _btn_style(Color("#141f36"), Color(0.25, 0.5, 0.62, 0.7)))
	b.add_theme_stylebox_override("hover", _btn_style(Color("#1c2c4c"), _accent))
	b.add_theme_stylebox_override("pressed", _btn_style(Color("#101a30"), _accent))
	b.add_theme_stylebox_override("focus", _btn_style(Color("#1c2c4c"), _accent))
	b.pressed.connect(func() -> void:
		Globals.play_sfx("click")
		on_pressed.call())
	parent.add_child(b)
	return b


func _overlay_base(parent: Node) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	parent.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	return overlay


func _panel_into(overlay: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.07, 0.14, 0.97)
	sb.border_color = Color(_accent.r, _accent.g, _accent.b, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 36.0
	sb.content_margin_right = 36.0
	sb.content_margin_top = 26.0
	sb.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	return v


# ------------------------------------------------------------------ api
func setup(player: Player, level_display_name: String, coin_total: int, accent: Color) -> void:
	_player = player
	_coin_total = coin_total
	_accent = accent
	set_coins(0)
	set_deaths(0)
	_update_labels()
	_show_toast(level_display_name)


func set_coins(n: int) -> void:
	_coin_count = n
	_update_labels()


func set_deaths(n: int) -> void:
	_death_count = n
	_update_labels()


func get_elapsed() -> float:
	return _elapsed


func _update_labels() -> void:
	if _coins_label != null:
		_coins_label.text = "SHARDS %d/%d" % [_coin_count, _coin_total]
		_deaths_label.text = "DEATHS %d" % _death_count


func _show_toast(text: String) -> void:
	_toast_label.text = text.to_upper()
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


func show_toast_message(text: String) -> void:
	## Public toast for level events (all-shards bonus etc.).
	_show_toast(text)


# ------------------------------------------------------------------ combo
func show_combo(n: int) -> void:
	if n < 2:
		_combo_label.modulate.a = 0.0
		return
	_combo_label.text = "STREAK x%d" % n
	_combo_label.self_modulate = Color.WHITE
	_combo_label.pivot_offset = Vector2(_combo_label.size.x / 2.0, 0.0)
	var tw := create_tween()
	_combo_label.scale = Vector2(1.25, 1.25)
	tw.set_parallel(true)
	tw.tween_property(_combo_label, "modulate:a", 1.0, 0.08)
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash_combo_lost(n: int) -> void:
	if _combo_label.modulate.a <= 0.0:
		return
	_combo_label.text = "STREAK LOST  (x%d)" % maxi(n, 2)
	_combo_label.self_modulate = Color("#fb7185")
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.35)


func hide_combo() -> void:
	var tw := create_tween()
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.2)


# ------------------------------------------------------------- transitions
func fade_out(duration := 0.18) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if timing and not _complete_overlay.visible:
		_elapsed += delta
	_time_label.text = Globals.format_time(_elapsed)
	if _player != null and is_instance_valid(_player):
		var r := _player.dash_ratio()
		_dash_fill.color.a = 1.0 if r >= 1.0 else 0.45
		_dash_fill.size.x = 106.0 * r


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _complete_overlay.visible:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func request_pause() -> void:
	## Called by on-screen touch controls.
	if not _complete_overlay.visible:
		_toggle_pause()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_overlay.visible = p
	Globals.play_sfx("click")
	if p and _resume_btn != null:
		_resume_btn.grab_focus()


func _on_resume() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


# ------------------------------------------------------------ completion
func show_complete(coins: int, deaths: int, is_last_level: bool,
		best_combo := 0) -> void:
	timing = false
	for c in _complete_stats_node.get_children():
		c.queue_free()
	_add_stat_line(_complete_stats_node, "TIME", Globals.format_time(_elapsed))
	_add_stat_line(_complete_stats_node, "SHARDS", "%d / %d" % [coins, _coin_total])
	_add_stat_line(_complete_stats_node, "DEATHS", str(deaths))
	if best_combo >= 2:
		_add_stat_line(_complete_stats_node, "BEST STREAK", "x%d" % best_combo)
	_next_btn.text = "FINAL RESULTS" if is_last_level else "NEXT LEVEL"
	_complete_overlay.visible = true
	_next_btn.grab_focus()


func _add_stat_line(parent: Node, key: String, value: String) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	var k := _make_label(key, 20, Color(0.6, 0.72, 0.88))
	k.custom_minimum_size = Vector2(120, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(k)
	var v := _make_label(value, 20, Color.WHITE)
	v.custom_minimum_size = Vector2(140, 0)
	h.add_child(v)
	parent.add_child(h)
