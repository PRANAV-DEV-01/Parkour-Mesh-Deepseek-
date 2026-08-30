extends Node
## E2E part 2: menu extras + alternate paths not covered by e2e.gd.
## HOW TO PLAY open/close, locked level buttons, unlock + save persistence,
## pause -> MAIN MENU, and the FINAL RESULTS -> PLAY AGAIN loop.


class Driver:
	extends Node

	var fails := 0

	func check(n: String, ok: bool, extra := "") -> void:
		print(("PASS: " if ok else "FAIL: ") + n + ("  " + extra if extra != "" else ""))
		if not ok:
			fails += 1

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func wait_scene(predicate: Callable, label: String, timeout_s := 8.0) -> Node:
		var t := 0.0
		while t < timeout_s:
			await get_tree().process_frame
			t += get_process_delta_time()
			var cs := get_tree().current_scene
			if cs != null and predicate.call(cs):
				return cs
		check("reached " + label, false, "timeout")
		return null

	func find_button(root: Node, text: String) -> Button:
		if root is Button and root.text == text:
			return root
		for c in root.get_children():
			var b := find_button(c, text)
			if b != null:
				return b
		return null

	func press(button_text: String, from: Node) -> bool:
		var b := find_button(from, button_text)
		if b == null:
			check("button exists: " + button_text, false)
			return false
		b.pressed.emit()
		return true

	func tap_key(keycode: Key) -> void:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.pressed = true
		Input.parse_input_event(ev)
		await frames(3)
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = keycode
		ev2.pressed = false
		Input.parse_input_event(ev2)
		await frames(2)

	func _ready() -> void:
		run_tests()

	func run_tests() -> void:
		# Fresh-save state.
		DirAccess.remove_absolute(Globals.SAVE_PATH)
		Globals.load_progress()
		check("fresh save starts with only level 1",
				Globals.unlocked_level == 0,
				"unlocked=%d" % Globals.unlocked_level)

		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		var menu := await wait_scene(
				func(cs: Node) -> bool: return cs.name == "MainMenu", "menu")
		if menu == null:
			return

		# Locked LEVEL 2 cannot be entered.
		var l2 := find_button(menu, "LEVEL 2  [LOCKED]")
		check("LEVEL 2 shown as locked", l2 != null)
		if l2 != null:
			check("locked LEVEL 2 button disabled", l2.disabled)
			l2.pressed.emit()
			await frames(20)
			check("pressing locked LEVEL 2 does nothing",
					get_tree().current_scene.name == "MainMenu")

		# HOW TO PLAY overlay open/close via real buttons (and Esc).
		var howto_btn := find_button(menu, "HOW TO PLAY")
		check("HOW TO PLAY button exists", howto_btn != null)
		if howto_btn != null and "_howto" in menu:
			howto_btn.pressed.emit()
			await frames(3)
			check("how-to overlay opens", menu._howto.visible)
			await tap_key(KEY_ESCAPE)
			await frames(2)
			check("Esc closes how-to overlay", not menu._howto.visible)
			howto_btn.pressed.emit()
			await frames(3)
			await press("GOT IT!", menu)
			await frames(2)
			check("GOT IT! closes how-to overlay", not menu._howto.visible)

		# Finish level 1 through the real pipeline -> unlocks level 2.
		Globals.current_level_index = 0
		Globals.finish_level(11.5, 3, 1, 4)
		await frames(10)
		check("finish_level unlocks next level", Globals.unlocked_level >= 1,
				"unlocked=%d" % Globals.unlocked_level)
		check("progress written to disk",
				FileAccess.file_exists(Globals.SAVE_PATH))
		Globals.load_progress()
		check("unlock survives save/load roundtrip", Globals.unlocked_level >= 1)

		# Reload the menu so buttons rebuild from new unlock state.
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		menu = await wait_scene(
				func(cs: Node) -> bool: return cs.name == "MainMenu", "menu again")
		if menu == null:
			return
		var l2_open := find_button(menu, "LEVEL 2")
		check("LEVEL 2 now selectable", l2_open != null)
		if l2_open != null:
			l2_open.pressed.emit()
			var lvl2 := await wait_scene(
					func(cs: Node) -> bool:
						return cs.is_in_group("level") \
								and cs.display_name.begins_with("LEVEL 2"),
					"level 2 via select")
			check("level select enters LEVEL 2", lvl2 != null)

		# Pause -> MAIN MENU returns to menu, unpaused.
		await tap_key(KEY_ESCAPE)
		check("pause works in selected level", get_tree().paused)
		var cur := get_tree().current_scene
		await press("MAIN MENU", cur)
		menu = await wait_scene(
				func(cs: Node) -> bool: return cs.name == "MainMenu",
				"menu from pause")
		if menu == null:
			return
		check("MAIN MENU exits to menu", true)
		check("game unpaused after exiting", not get_tree().paused)

		# FINAL RESULTS -> PLAY AGAIN loops back to LEVEL 1.
		Globals.load_level(2)
		var lvl3 := await wait_scene(
				func(cs: Node) -> bool: return cs.is_in_group("level"),
				"level 3")
		if lvl3 == null:
			return
		var player: Player = lvl3.get_node("Player")
		var goal: GoalPortal = lvl3.get_node_or_null("Extras/Goal")
		check("level 3 goal exists", goal != null)
		player.global_position = goal.global_position
		player.velocity = Vector2.ZERO
		var hud: GameHUD = lvl3.get_node("HUD")
		var t := 0.0
		while t < 6.0 and not hud._complete_overlay.visible:
			await get_tree().process_frame
			t += get_process_delta_time()
		check("portal completes level 3", hud._complete_overlay.visible)
		await press("FINAL RESULTS", get_tree().current_scene)
		var win := await wait_scene(
				func(cs: Node) -> bool: return cs.name == "WinScreen",
				"win screen")
		if win == null:
			return
		await press("PLAY AGAIN", win)
		var lvl1 := await wait_scene(
				func(cs: Node) -> bool:
					return cs.is_in_group("level") \
							and cs.display_name.begins_with("LEVEL 1"),
				"level 1 via play again")
		check("PLAY AGAIN restarts run at LEVEL 1", lvl1 != null)

		print("E2E2_DONE failures=%d" % fails)
		get_tree().quit(1 if fails > 0 else 0)


func _ready() -> void:
	var d := Driver.new()
	d.name = "E2E2Driver"
	get_tree().root.add_child.call_deferred(d)
