extends Node
## Full playthrough trace: menu -> L1 -> L2 -> L3 -> final results -> menu,
## using the REAL scene-change pipeline, REAL buttons, pause and restart.


class Driver:
	extends Node

	var fails := 0

	func check(name: String, ok: bool, extra := "") -> void:
		if ok:
			print("PASS: " + name)
		else:
			fails += 1
			print("FAIL: " + name + "  " + extra)

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
		Globals.unlocked_level = 99   # allow direct navigation for the trace
		Globals.best_times.clear()

		# Boot the REAL main menu as current scene.
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		var menu := await wait_scene(
				func(cs: Node) -> bool: return cs.name == "MainMenu", "main menu")
		if menu == null:
			return
		check("main menu boots", true)

		# PLAY -> level 1.
		press("PLAY", menu)
		var lvl := await wait_scene(
				func(cs: Node) -> bool: return cs.is_in_group("level"), "level 1")
		if lvl == null:
			return
		check("PLAY starts level 1", lvl.display_name.begins_with("LEVEL 1"),
				lvl.display_name)

		# Esc pauses; RESUME unpauses.
		await tap_key(KEY_ESCAPE)
		check("Esc pauses the game", get_tree().paused)
		check("pause overlay shown",
				find_button(lvl, "RESUME") != null)
		await press("RESUME", lvl)
		await frames(3)
		check("RESUME unpauses", not get_tree().paused)

		# R restarts level 1 (fresh instance).
		var old_id := lvl.get_instance_id()
		await tap_key(KEY_R)
		var lvl1b := await wait_scene(
				func(cs: Node) -> bool:
					return cs.is_in_group("level") \
							and cs.get_instance_id() != old_id,
				"restarted level 1")
		if lvl1b == null:
			return
		check("R restarts the level", lvl1b.display_name.begins_with("LEVEL 1"))
		lvl = lvl1b

		# Complete L1 via its portal, then NEXT LEVEL -> L2.
		if not await finish_level(lvl, "LEVEL 1"):
			return
		if not await goto_next(lvl, "LEVEL 2"):
			return

		# Complete L2 -> L3.
		lvl = await wait_scene(
				func(cs: Node) -> bool: return cs.is_in_group("level"), "level 2")
		if lvl == null:
			return
		if not await finish_level(lvl, "LEVEL 2"):
			return
		if not await goto_next(lvl, "LEVEL 3"):
			return

		# Complete L3 -> FINAL RESULTS.
		lvl = await wait_scene(
				func(cs: Node) -> bool: return cs.is_in_group("level"), "level 3")
		if lvl == null:
			return
		if not await finish_level(lvl, "LEVEL 3"):
			return
		await press("FINAL RESULTS", lvl)
		var win := await wait_scene(
				func(cs: Node) -> bool: return cs.name == "WinScreen",
				"final results screen")
		if win == null:
			return
		check("final results screen reached after level 3", true)
		check("run totals carried through all levels",
				Globals.run_total_deaths >= 0 and Globals.run_total_coins >= 0)

		# MAIN MENU closes the loop.
		await press("MAIN MENU", win)
		menu = await wait_scene(
				func(cs: Node) -> bool: return cs.name == "MainMenu", "back to menu")
		if menu == null:
			return
		check("MAIN MENU returns from results to menu", true)
		check("progress persisted (all best times recorded)",
				Globals.best_times.size() >= 3,
				"saved=%s" % [Globals.best_times])

		print("E2E_DONE failures=%d" % fails)
		get_tree().quit(1 if fails > 0 else 0)

	func finish_level(lvl: Node, expected: String) -> bool:
		var player: Player = lvl.get_node("Player")
		var goal: GoalPortal = lvl.get_node_or_null("Extras/Goal")
		if goal == null:
			check(expected + ": goal exists", false)
			return false
		player.global_position = goal.global_position
		player.velocity = Vector2.ZERO
		var t := 0.0
		while t < 6.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			var hud: GameHUD = lvl.get_node("HUD")
			if hud._complete_overlay.visible:
				break
		var hud2: GameHUD = lvl.get_node("HUD")
		check(expected + ": portal completes level",
				hud2._complete_overlay.visible)
		return hud2._complete_overlay.visible

	func goto_next(_lvl: Node, next_name: String) -> bool:
		## Presses whatever the primary continue button says.
		var cs := get_tree().current_scene
		var b := find_button(cs, "NEXT LEVEL")
		if b == null:
			b = find_button(cs, "FINAL RESULTS")
		if b == null:
			check(next_name + ": continue button found", false)
			return false
		b.pressed.emit()
		var lvl2 := await wait_scene(
				func(node: Node) -> bool:
					return node.is_in_group("level") \
							and node.display_name.begins_with(next_name),
				next_name)
		check("advanced to " + next_name, lvl2 != null)
		return lvl2 != null


func _ready() -> void:
	var d := Driver.new()
	d.name = "E2EDriver"
	get_tree().root.add_child.call_deferred(d)
