extends Node
## Mechanics sandbox: springs, crumble lifecycle, moving-platform riding,
## wall-jump air-move refresh, coyote time, jump buffer, variable jump cut.
## Builds its own tiny world from the REAL game classes.


class Runner:
	extends Node

	var fails := 0
	var player: Player

	func check(n: String, ok: bool, extra := "") -> void:
		print(("PASS: " if ok else "FAIL: ") + n + ("  " + extra if extra != "" else ""))
		if not ok:
			fails += 1

	func pframes(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func settle(pos: Vector2) -> void:
		_release_all()
		player.global_position = pos
		player.velocity = Vector2.ZERO
		await pframes(12)

	func _release_all() -> void:
		for a in ["move_left", "move_right", "jump", "dash"]:
			Input.action_release(a)

	func grounded() -> bool:
		return player.is_on_floor()

	func wait_until(pred: Callable, timeout_frames: int, label: String) -> bool:
		for i in timeout_frames:
			await get_tree().physics_frame
			if pred.call():
				check(label, true)
				return true
		check(label, false, "(timeout)")
		return false

	func _ready() -> void:
		run_tests()

	func run_tests() -> void:
		await t_spring()
		await t_crumble_lifecycle()
		await t_mover_ride()
		await t_wall_jump_refresh()
		await t_coyote_time()
		await t_jump_buffer()
		await t_jump_cut()
		await t_landing_refresh()
		print("MECH_DONE failures=%d" % fails)
		get_tree().quit(1 if fails > 0 else 0)

	# ---------------------------------------------------------------- tests
	func t_spring() -> void:
		await settle(Vector2(-140, -160))
		var min_vy := 0.0
		var max_vy := 0.0
		for i in 45:
			await get_tree().physics_frame
			min_vy = minf(min_vy, player.velocity.y)
			max_vy = maxf(max_vy, player.velocity.y)
		check("spring launches the player", min_vy <= -800.0, "vy=%d" % min_vy)
		check("spring does not double-fire (single bounce)",
				max_vy < 200.0 or min_vy > -1400.0,
				"min=%d max=%d" % [min_vy, max_vy])

	func t_crumble_lifecycle() -> void:
		var crumble: CrumblePlatform = null
		for n in get_parent().get_children():
			if n is CrumblePlatform:
				crumble = n
		if crumble == null:
			check("crumble platform exists", false)
			return
		await settle(Vector2(40, -230))
		await wait_until(func() -> bool: return crumble._state == "shaking",
				30, "stepping on crumble starts shake")
		await wait_until(func() -> bool: return crumble._state == "gone",
				90, "crumble breaks after shake")
		await wait_until(func() -> bool: return crumble._shape.disabled,
				10, "crumble collision removed when broken")
		await settle(Vector2(-350, -60))
		await wait_until(func() -> bool:
				return crumble._state == "idle" and not crumble._shape.disabled,
				360, "crumble rebuilds once player is away (no ghost)")

	func t_mover_ride() -> void:
		var mover: MovingPlatform = null
		for n in get_parent().get_children():
			if n is MovingPlatform:
				mover = n
		if mover == null:
			check("moving platform exists", false)
			return
		await settle(Vector2(430, -330))
		var on_it := await wait_until(
				func() -> bool:
					return grounded() \
							and absf(player.global_position.y + 299.0) < 14.0,
				120, "player lands on moving platform")
		if not on_it:
			return
		var x0 := player.global_position.x
		await pframes(50)
		var x1 := player.global_position.x
		check("rider is carried by moving platform", x1 - x0 <= -40.0,
				"dx=%d" % int(x1 - x0))
		check("rider still glued mid-ride", grounded())

	func t_wall_jump_refresh() -> void:
		await settle(Vector2(100, -60))
		Input.action_press("move_right")
		var on_wall := await wait_until(
				func() -> bool: return player.is_on_wall(),
				120, "player reaches the wall")
		if not on_wall:
			Input.action_release("move_right")
			return
		# Ground jump first (wall base is on the floor), stay glued while
		# falling so we are genuinely AIRBORNE on the wall.
		Input.action_press("jump")
		await pframes(2)
		Input.action_release("jump")
		var sliding := await wait_until(
				func() -> bool:
					return not grounded() and player.is_on_wall_only() \
							and player.velocity.y > 0.0,
				120, "player slides down the wall mid-air")
		if not sliding:
			Input.action_release("move_right")
			return
		player._jumps_used = 2   # simulate exhausted double jump
		Input.action_press("jump")
		await pframes(3)
		Input.action_release("jump")
		Input.action_release("move_right")
		check("wall jump kicks away from wall (input lockout)",
				player.velocity.x <= -250.0, "vx=%d" % int(player.velocity.x))
		check("wall jump refreshes air jump",
				player._jumps_used <= 1, "jumps_used=%d" % player._jumps_used)
		check("wall jump launches upward", player.velocity.y <= -400.0,
				"vy=%d" % int(player.velocity.y))

	func t_coyote_time() -> void:
		await settle(Vector2(250, -60))   # near right edge of ground (edge=350)
		Input.action_press("move_right")
		var walked_off := false
		for i in 180:
			await get_tree().physics_frame
			if walked_off:
				break
			if not grounded():
				walked_off = true
				break
		Input.action_release("move_right")
		check("player walks off ledge", walked_off)
		# Within coyote window (< 0.11s ~ 6 physics frames): jump must fire.
		await pframes(2)
		player._jumps_used = 2   # isolate: no double jump available
		Input.action_press("jump")
		await pframes(2)
		Input.action_release("jump")
		var vy := player.velocity.y
		check("coyote jump fires just after leaving ledge", vy <= -450.0,
				"vy=%d" % int(vy))

	func t_jump_buffer() -> void:
		await settle(Vector2(0, -520))
		player._jumps_used = 2   # no air moves; only buffer can save this
		# Press jump just before touchdown (within the 0.13s buffer window).
		var near_ground := await wait_until(
				func() -> bool: return player.global_position.y >= -130.0,
				90, "player falls to jump-buffer height")
		if not near_ground:
			return
		Input.action_press("jump")
		await pframes(2)
		Input.action_release("jump")
		var fired := false
		for i in 12:
			await get_tree().physics_frame
			if player.velocity.y <= -450.0:
				fired = true
				break
		check("buffered jump fires on landing", fired)

	func t_jump_cut() -> void:
		await settle(Vector2(-60, -60))
		Input.action_press("jump")
		await pframes(7)   # ~0.12s of hold while rising
		var vr := player.velocity.y
		Input.action_release("jump")
		await pframes(3)
		var va := player.velocity.y
		var dv := va - vr
		check("releasing jump early cuts rise (variable height)", dv >= 150.0,
				"vr=%d va=%d dv=%d" % [int(vr), int(va), int(dv)])

	func t_landing_refresh() -> void:
		await settle(Vector2(0, -300))
		await wait_until(func() -> bool: return grounded(), 120,
				"player lands back on ground")
		check("landing restores double jump", player._jumps_used == 0,
				"jumps_used=%d" % player._jumps_used)
		check("landing restores dash", player._can_dash)


func _ready() -> void:
	# Sandbox world built from real classes.
	var ground := Platform.new()
	ground.size = Vector2(700, 40)
	ground.position = Vector2(0, 0)
	add_child(ground)

	var wall := Platform.new()
	wall.size = Vector2(24, 240)
	wall.position = Vector2(160, -160)
	add_child(wall)

	var spring := SpringPad.new()
	spring.position = Vector2(-140, -20)
	add_child(spring)

	var crumble := CrumblePlatform.new()
	crumble.size = Vector2(150, 26)
	crumble.position = Vector2(40, -170)
	add_child(crumble)

	var mover := MovingPlatform.new()
	mover.size = Vector2(170, 22)
	mover.move_offset = Vector2(-160, 0)
	mover.duration = 1.8
	mover.position = Vector2(420, -260)
	add_child(mover)

	var p := Player.new()
	p.position = Vector2(0, -80)
	add_child(p)

	var runner := Runner.new()
	runner.player = p
	runner.name = "MechRunner"
	add_child(runner)
