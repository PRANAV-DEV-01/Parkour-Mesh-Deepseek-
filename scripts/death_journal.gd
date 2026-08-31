extends Control
## Death Journal scene - a scrollable, data-driven list of every recorded
## death. Levels with zero deaths get a star; levels with deaths get one entry
## per death. Opened from the main menu; Close returns to the main menu.


func _ready() -> void:
	_build()


func _build() -> void:
	# Full-screen dim backdrop.
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "DEATH JOURNAL"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#67e8f9"))
	title.add_theme_color_override("font_outline_color", Color("#0e7490"))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 50
	title.offset_bottom = 120
	add_child(title)

	var close := Button.new()
	close.text = "CLOSE"
	close.add_theme_font_size_override("font_size", 22)
	close.custom_minimum_size = Vector2(220, 48)
	close.add_theme_stylebox_override("normal", _btn_style(Color("#141f36"), Color(0.25, 0.5, 0.62, 0.7)))
	close.add_theme_stylebox_override("hover", _btn_style(Color("#1c2c4c"), Color("#22d3ee")))
	close.add_theme_stylebox_override("pressed", _btn_style(Color("#101a30"), Color("#22d3ee")))
	close.anchors_preset = Control.PRESET_CENTER_BOTTOM
	close.offset_top = -70
	close.offset_bottom = -22
	close.grow_horizontal = Control.GROW_DIRECTION_BOTH
	close.pressed.connect(_on_close)
	add_child(close)

	# Scrollable entry list.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 120
	scroll.offset_right = -120
	scroll.offset_top = 130
	scroll.offset_bottom = -90
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var journal: Array = PlayerMemory.memory["death_journal"]
	var level_count := Globals.LEVELS.size()

	if journal.is_empty():
		var empty := _entry_label("No deaths yet. Keep running!", Color("#9be8ff"))
		vbox.add_child(empty)
	else:
		# Star for levels with zero recorded deaths.
		var zero_levels := []
		for i in level_count:
			if PlayerMemory.get_death_count(i) == 0:
				zero_levels.append(i)
		for li in zero_levels:
			var star := _entry_label(Globals.LEVEL_NAMES[li]
					+ "   ⭐  CLEAN RUN!", Color("#fde68a"))
			vbox.add_child(star)

		# One line per death, newest first.
		var entries := journal.duplicate()
		entries.reverse()
		for e in entries:
			if not e is Dictionary:
				continue
			var lvl := int(e.get("level", 0))
			var name := Globals.LEVEL_NAMES[lvl] if lvl < level_count else "L%d" % (lvl + 1)
			var t := _format_time(e.get("time", 0.0))
			var d := str(e.get("date", "??"))
			var pos: Variant = e.get("position", {})
			var px: Variant = (pos.get("x") if pos is Dictionary else 0)
			var py: Variant = (pos.get("y") if pos is Dictionary else 0)
			var line := "%s  •  time %s  •  %s  •  pos(%.0f, %.0f)" % [
				name, t, d, float(px), float(py),
			]
			vbox.add_child(_entry_label(line, Color("#fda4af")))


func _format_time(t: Variant) -> String:
	var seconds := float(t)
	return "%02d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func _entry_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _on_close() -> void:
	Globals.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu_cyber.tscn")
