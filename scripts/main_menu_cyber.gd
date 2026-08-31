extends Control
## Cyberpunk grid main menu (scene: scenes/ui/main_menu_cyber.tscn).
## Background grid + scanlines animate via the grid shader on the Background
## ColorRect; all text/buttons are built here with the default theme font.

const CYAN := Color("#22d3ee")
const CYAN_BRIGHT := Color("#67e8f9")
const ORANGE := Color("#ff8c00")
const WHITE := Color("#e8fbff")

var _level_select_panel: Control
var _credits_panel: Control
var _title: Label
var _bg_material: ShaderMaterial
var _pulse := 0.0

func _ready() -> void:
	_build_background()
	_build_title()
	_build_menu()
	_build_slogan()
	_build_corporate()
	_build_level_select()
	_build_credits()
	_maybe_show_daily_memory()
	PlayerMemory.record_session_start()


func _build_background() -> void:
	var bg := get_node_or_null("Background")
	if bg is ColorRect and bg.material is ShaderMaterial:
		_bg_material = bg.material


func _build_title() -> void:
	var tag := Label.new()
	tag.text = "TRACE THE GRID"
	tag.add_theme_font_size_override("font_size", 24)
	tag.add_theme_color_override("font_color", Color("#5eead4"))
	tag.add_theme_color_override("font_outline_color", CYAN)
	tag.add_theme_constant_override("outline_size", 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.anchors_preset = Control.PRESET_TOP_WIDE
	tag.anchor_top = 0.0
	tag.anchor_bottom = 0.0
	tag.anchor_left = 0.0
	tag.anchor_right = 1.0
	tag.offset_top = 78
	tag.offset_bottom = 112
	add_child(tag)

	_title = Label.new()
	_title.text = "PARKOUR MESH"
	_title.add_theme_font_size_override("font_size", 92)
	_title.add_theme_color_override("font_color", Color("#d8fff8"))
	_title.add_theme_color_override("font_outline_color", Color("#0891b2"))
	_title.add_theme_constant_override("outline_size", 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.anchor_top = 0.0
	_title.anchor_bottom = 0.0
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.offset_top = 96
	_title.offset_bottom = 232
	add_child(_title)


func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -220
	col.offset_right = 220
	col.offset_top = 120
	col.offset_bottom = -180
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(col)

	var play := _cyber_button("PLAY", Color("#20cfe0"), true)
	col.add_child(play)
	play.pressed.connect(_on_play_pressed)

	var sub := Label.new()
	sub.text = "OUR RULES  OUR PATH"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var ls := _cyber_button("LEVEL SELECT", CYAN, false)
	col.add_child(ls)
	ls.pressed.connect(_on_level_select_pressed)

	var cred := _cyber_button("CREDITS", CYAN, false)
	col.add_child(cred)
	cred.pressed.connect(_on_credits_pressed)

	var journal := _cyber_button("DEATH JOURNAL", CYAN, false)
	col.add_child(journal)
	journal.pressed.connect(_on_journal_pressed)


func _cyber_button(text: String, accent: Color, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30 if primary else 26)
	b.add_theme_color_override("font_color", WHITE if primary else Color("#cdeeff"))
	b.add_theme_color_override("font_hover_color", WHITE)
	b.custom_minimum_size = Vector2(360, 62 if primary else 52)
	b.pivot_offset = Vector2(180, 26)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.7)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	hover.border_color = Color(1, 1, 1)
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(6)
	b.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.05, 0.03, 0.0, 0.9)
	pressed.border_color = ORANGE
	pressed.set_border_width_all(3)
	pressed.set_corner_radius_all(6)
	b.add_theme_stylebox_override("pressed", pressed)

	var focus := hover.duplicate()
	b.add_theme_stylebox_override("focus", focus)

	b.mouse_entered.connect(func() -> void:
		b.scale = Vector2(1.05, 1.05))
	b.mouse_exited.connect(func() -> void:
		b.scale = Vector2.ONE)
	b.pressed.connect(func() -> void:
		if Globals.has_method("play_sfx"):
			Globals.play_sfx("click"))
	return b


func _build_slogan() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_top = -96
	bar.offset_bottom = -46
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.01, 0.02, 0.85)
	sb.border_color = Color(0.2, 1, 1)
	sb.set_border_width_all(2)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var lbl := Label.new()
	lbl.text = "RUN JUMP CLIMB NEON REPEAT"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.4, 0.5, 0.6))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(lbl)


func _build_corporate() -> void:
	var tag := Label.new()
	tag.text = "CORP-X7   |   未来走"
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85, 0.55))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tag.anchor_top = 1.0
	tag.anchor_bottom = 1.0
	tag.anchor_left = 0.0
	tag.anchor_right = 1.0
	tag.offset_top = -30
	tag.offset_bottom = -8
	add_child(tag)


func _on_play_pressed() -> void:
	Globals.start_game(0)


func _on_level_select_pressed() -> void:
	_fill_level_select()
	_level_select_panel.visible = true


func _on_credits_pressed() -> void:
	_credits_panel.visible = true


func _on_journal_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/death_journal.tscn")


func _maybe_show_daily_memory() -> void:
	if PlayerMemory.get_today_string() != String(PlayerMemory.memory["last_session_date"]):
		_show_daily_popup()


func _show_daily_popup() -> void:
	var pop := Control.new()
	pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pop)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.1, 0.98)
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 46.0
	sb.content_margin_right = 46.0
	sb.content_margin_top = 34.0
	sb.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)

	var head := Label.new()
	head.text = "DAILY MEMORY"
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", CYAN_BRIGHT)
	head.add_theme_color_override("font_outline_color", Color("#0e7490"))
	head.add_theme_constant_override("outline_size", 6)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)

	var today := PlayerMemory.get_today_string()
	var yesterday := PlayerMemory.get_yesterday_string()
	var y_deaths := PlayerMemory.get_deaths_on_date(yesterday)
	var msg := "Yesterday you died %d times. Today, run faster!" % y_deaths
	if PlayerMemory.memory["last_session_date"] != today \
			and String(PlayerMemory.memory["last_session_date"]) != "":
		msg = "A fresh day on the grid. Yesterday: %d falls. Today we fly past them!" % y_deaths

	var body := Label.new()
	body.text = msg
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color("#d8fff8"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)

	var cont := Button.new()
	cont.text = "CONTINUE"
	cont.add_theme_font_size_override("font_size", 24)
	cont.custom_minimum_size = Vector2(220, 56)
	cont.add_theme_stylebox_override("normal", _popup_btn(Color(0, 0, 0, 0.7), Color(0.2, 1, 1)))
	cont.add_theme_stylebox_override("hover", _popup_btn(Color(0.02, 0.05, 0.08, 0.9), Color.WHITE))
	cont.add_theme_stylebox_override("pressed", _popup_btn(Color(0.05, 0.03, 0.0, 0.9), ORANGE))
	cont.pressed.connect(func() -> void:
		Globals.play_sfx("click")
		pop.queue_free())
	v.add_child(cont)


func _popup_btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	return sb


# ---------------------------------------------------------------- overlays
func _overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	return ov


func _build_level_select() -> void:
	var ov := _overlay()
	_level_select_panel = ov
	var back := _cyber_button("BACK", Color(0.45, 0.7, 0.9), false)
	back.custom_minimum_size = Vector2(200, 44)
	back.pivot_offset = Vector2(100, 22)
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 22)
	back.anchors_preset = Control.PRESET_TOP_LEFT
	back.anchor_left = 0.0
	back.anchor_top = 0.0
	back.offset_left = 40
	back.offset_top = 30
	back.offset_right = 240
	back.offset_bottom = 74
	back.pressed.connect(func() -> void: ov.visible = false)
	ov.add_child(back)

	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", CYAN_BRIGHT)
	title.add_theme_color_override("font_outline_color", Color("#0e7490"))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_TOP_WIDE
	title.offset_top = 70
	title.offset_bottom = 130
	ov.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 24)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.anchor_left = 0.5
	grid.anchor_right = 0.5
	grid.anchor_top = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -300
	grid.offset_right = 300
	grid.offset_top = -60
	grid.offset_bottom = 120
	ov.add_child(grid)

	for i in Globals.LEVELS.size():
		var locked: bool = i > Globals.unlocked_level
		var stars: int = 0 if locked else Globals.stars_for_level(i)
		var b := _cyber_button("", CYAN, false)
		b.text = "LEVEL %d   %s%s" % [
			i + 1,
			("★".repeat(stars) + "☆☆☆").left(3),
			"  [LOCKED]" if locked else "",
		]
		b.custom_minimum_size = Vector2(280, 48)
		b.pivot_offset = Vector2(140, 24)
		b.add_theme_font_size_override("font_size", 18)
		if locked:
			b.disabled = true
		else:
			var idx := i
			b.pressed.connect(func() -> void: Globals.start_game(idx))
		grid.add_child(b)


func _build_credits() -> void:
	var ov := _overlay()
	_credits_panel = ov
	var back := _cyber_button("", Color(0.45, 0.7, 0.9), false)
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 22)
	back.custom_minimum_size = Vector2(200, 44)
	back.pivot_offset = Vector2(100, 22)
	back.anchors_preset = Control.PRESET_TOP_LEFT
	back.offset_left = 40
	back.offset_top = 30
	back.offset_right = 240
	back.offset_bottom = 74
	back.pressed.connect(func() -> void: ov.visible = false)
	ov.add_child(back)

	var title := Label.new()
	title.text = "CREDITS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", CYAN_BRIGHT)
	title.add_theme_color_override("font_outline_color", Color("#0e7490"))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_TOP_WIDE
	title.offset_top = 70
	title.offset_bottom = 130
	ov.add_child(title)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -240
	col.offset_right = 240
	col.offset_top = -120
	col.offset_bottom = 120
	ov.add_child(col)

	var lines := [
		["GAME DESIGN & CODE", "Parkour Mesh Team"],
		["ART / AUDIO", "Procedural (synth + shaders)"],
		["ENGINE", "Godot 4.3"],
		["THANKS FOR PLAYING", "Keep tracing the grid."],
	]
	for pair in lines:
		var h := Label.new()
		h.text = "%s   -   %s" % [pair[0], pair[1]]
		h.add_theme_font_size_override("font_size", 20)
		h.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.95))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(h)


func _fill_level_select() -> void:
	pass


func _process(delta: float) -> void:
	_pulse += delta
	if _title != null:
		var p := 0.5 + 0.5 * sin(_pulse * 2.0)
		_title.add_theme_color_override("font_outline_color",
				Color("#0891b2").lerp(Color("#22d3ee"), p))
		if _bg_material != null and _bg_material.get_shader_parameter("grid_strength") != null:
			_bg_material.set_shader_parameter("grid_strength", 0.20 + 0.03 * sin(_pulse))
