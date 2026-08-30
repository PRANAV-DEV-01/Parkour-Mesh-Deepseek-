extends Node
## Headless bug-bash harness: boots level scenes, forces deaths,
## verifies respawn/hazard/combo behaviour, prints PASS/FAIL, quits.

var failures := 0

func _ready() -> void:
	await _run_tests()
	print("TESTS_DONE failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(name: String, ok: bool, extra := "") -> void:
	if ok:
		print("PASS: " + name)
	else:
		failures += 1
		print("FAIL: " + name + "  " + extra)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _load_level(path: String) -> Node2D:
	var lvl: Node2D = (load(path) as PackedScene).instantiate()
	add_child(lvl)
	await _frames(5)
	return lvl


func _kill_at(player: Player, pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await _frames(12)


func _test_spike_death_respawn() -> void:
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var player: Player = lvl.get_node("Player")
	var start_pos: Vector2 = player.global_position
	await _kill_at(player, Vector2(2170, -40))
	_check("spike contact kills player", player._is_dead)
	await get_tree().create_timer(2.5).timeout
	await _frames(5)
	_check("player respawns after spike death", not player._is_dead,
			"is_dead=%s" % player._is_dead)
	_check("player respawns at spawn point",
			player.global_position.distance_to(start_pos) < 60.0,
			"pos=%s" % player.global_position)
	_check("player collision restored", not player._collision_shape.disabled)

	# Die a SECOND time right away - exercises the repeat-death pipeline.
	await _kill_at(player, Vector2(2170, -40))
	_check("second spike death kills player", player._is_dead)
	await get_tree().create_timer(2.5).timeout
	await _frames(5)
	_check("player respawns after SECOND spike death", not player._is_dead,
			"is_dead=%s pos=%s" % [player._is_dead, player.global_position])
	lvl.queue_free()
	await _frames(3)


func _test_rapid_double_death() -> void:
	## Death arriving DURING a respawn cycle must still be honoured.
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var player: Player = lvl.get_node("Player")
	var start_pos: Vector2 = player.global_position
	await _kill_at(player, Vector2(2170, -40))
	# Wait only ~0.3s (mid respawn-wait), kill again via kill_y.
	await get_tree().create_timer(0.3).timeout
	player.global_position.y = lvl.kill_y + 100
	await _frames(10)
	await get_tree().create_timer(4.0).timeout
	await _frames(5)
	_check("death during respawn cycle still respawns", not player._is_dead,
			"is_dead=%s" % player._is_dead)
	_check("post-rapid-death position sane",
			player.global_position.distance_to(start_pos) < 80.0,
			"pos=%s" % player.global_position)
	lvl.queue_free()
	await _frames(3)


func _test_checkpoint_respawn() -> void:
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var player: Player = lvl.get_node("Player")
	var cp: Checkpoint = lvl.get_node("Extras/Checkpoint1")
	var cp_expected: Vector2 = cp.spawn_position()
	player.global_position = cp.global_position + Vector2(0, -20)
	player.velocity = Vector2.ZERO
	await _frames(10)
	_check("checkpoint activates on touch", cp.is_active)
	_check("level registered checkpoint pos",
			lvl.checkpoint_pos.distance_to(cp_expected) < 1.0)
	await _kill_at(player, Vector2(2170, -40))
	await get_tree().create_timer(2.5).timeout
	_check("post-checkpoint death respawns at checkpoint",
			not player._is_dead and player.global_position.distance_to(cp_expected) < 60.0,
			"pos=%s want~%s" % [player.global_position, cp_expected])
	lvl.queue_free()
	await _frames(3)


func _test_ground_dash_not_cancelled() -> void:
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var player: Player = lvl.get_node("Player")
	# Settle onto the starting ground.
	await _frames(30)
	var x_before := player.global_position.x
	Input.action_press("move_right")
	await _frames(2)
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")
	var dash_frames := 0
	for i in 20:
		await get_tree().physics_frame
		if player._dash_timer > 0.0:
			dash_frames += 1
	Input.action_release("move_right")
	_check("ground dash persists (not instantly cancelled)", dash_frames >= 8,
			"dash_frames=%d" % dash_frames)
	_check("ground dash moved the player",
			player.global_position.x - x_before > 60.0,
			"dx=%.1f" % (player.global_position.x - x_before))
	lvl.queue_free()
	await _frames(3)


func _test_drone_and_laser_kill() -> void:
	var lvl := await _load_level("res://scenes/level_2.tscn")
	var player: Player = lvl.get_node("Player")
	var drone: Drone = lvl.get_node("Extras/Drone1")
	await _kill_at(player, drone.global_position)
	_check("drone contact kills player", player._is_dead)
	await get_tree().create_timer(2.5).timeout
	_check("respawn works after drone death", not player._is_dead)
	lvl.queue_free()
	await _frames(3)

	lvl = await _load_level("res://scenes/level_2.tscn")
	player = lvl.get_node("Player")
	var laser: LaserBeam = lvl.get_node("Extras/Laser1")
	# Sit exactly ON the beam line (rotated into the beam's current
	# direction) and wait for the sweep to register the overlap.
	player.velocity = Vector2.ZERO
	var waited := 0.0
	while not player._is_dead and waited < 4.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if not player._is_dead:
			player.global_position = laser.global_position \
					+ Vector2(laser.length * 0.6, 0).rotated(laser.rotation)
			player.velocity = Vector2.ZERO
	_check("laser beam kills player", player._is_dead, "waited=%.1f" % waited)
	lvl.queue_free()
	await _frames(3)


func _test_combo_system() -> void:
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var player: Player = lvl.get_node("Player")
	# Use distant shards (Coin1 sits near spawn and is auto-grabbed on boot
	# in old builds - now moved; these two are safely far away).
	var c1: Coin = lvl.get_node("Pickups/Coin4")
	var c2: Coin = lvl.get_node("Pickups/Coin5")
	player.global_position = c1.global_position
	await _frames(8)
	_check("first shard registers", lvl.level_coins == 1, "coins=%d" % lvl.level_coins)
	_check("combo starts at 1", lvl.combo == 1, "combo=%d" % lvl.combo)
	player.global_position = c2.global_position
	await _frames(8)
	_check("second shard registers", lvl.level_coins == 2, "coins=%d" % lvl.level_coins)
	_check("combo climbs to 2", lvl.combo == 2, "combo=%d" % lvl.combo)
	# Let the combo window lapse.
	await get_tree().create_timer(GameLevel.COMBO_WINDOW + 0.5).timeout
	_check("combo expires after window", lvl.combo == 0, "combo=%d" % lvl.combo)
	lvl.queue_free()
	await _frames(3)


func _test_all_levels_boot() -> void:
	for path in ["res://scenes/level_1.tscn", "res://scenes/level_2.tscn",
			"res://scenes/level_3.tscn"]:
		var lvl := await _load_level(path)
		var player: Player = lvl.get_node("Player")
		_check(path + " boots with live player",
				not player._is_dead and player.cam != null)
		lvl.queue_free()
		await _frames(3)


func _test_goal_finishes_and_saves() -> void:
	Globals.best_times.clear()
	Globals.unlocked_level = 0
	var lvl := await _load_level("res://scenes/level_1.tscn")
	var goal: GoalPortal = lvl.get_node("Extras/Goal")
	var player: Player = lvl.get_node("Player")
	player.global_position = goal.global_position + Vector2(0, -10)
	player.velocity = Vector2.ZERO
	await _frames(15)
	_check("goal triggers completion", lvl.completed)
	_check("goal disables player control", not player.active)
	_check("beating L1 unlocks L2", Globals.unlocked_level >= 1)
	_check("best time recorded for L1", Globals.best_times.has(0))
	lvl.queue_free()
	await _frames(3)


func _test_save_persistence() -> void:
	Globals.unlocked_level = 2
	Globals.best_times[1] = 42.5
	Globals.save_progress()
	Globals.best_times.clear()
	Globals.unlocked_level = 0
	Globals.load_progress()
	_check("save/load roundtrip keeps unlocked level", Globals.unlocked_level == 2,
			"unlocked=%d" % Globals.unlocked_level)
	_check("save/load roundtrip keeps best time",
			absf(float(Globals.best_times.get(1, -1.0)) - 42.5) < 0.01,
			"t=%s" % Globals.best_times.get(1))


func _test_music_loops_cleanly() -> void:
	var s := Globals._music_player.stream as AudioStreamWAV
	_check("music stream exists", s != null)
	_check("music loops forward", s.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var frames := s.data.size() / 2   # 16-bit mono
	_check("loop covers whole buffer exactly", s.loop_end == frames,
			"loop_end=%d frames=%d" % [s.loop_end, frames])
	# No silent padding tail: last ~100 ms must contain audio energy.
	var bytes := s.data
	var n := bytes.size()
	var energy := 0
	var i := n - 2206   # even offset, ~50ms window, decode-safe (i+2 <= n)
	while i < n - 1:
		energy += absi(bytes.decode_s16(i))
		i += 2
	_check("no dead-air gap at loop point", energy > 1000,
			"tail_energy=%d" % energy)


func _run_tests() -> void:
	await _test_spike_death_respawn()
	await _test_rapid_double_death()
	await _test_checkpoint_respawn()
	await _test_ground_dash_not_cancelled()
	await _test_drone_and_laser_kill()
	await _test_combo_system()
	await _test_all_levels_boot()
	await _test_goal_finishes_and_saves()
	await _test_save_persistence()
	await _test_music_loops_cleanly()
