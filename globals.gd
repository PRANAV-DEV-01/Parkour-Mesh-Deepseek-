extends Node
## Global game state, procedural audio synthesis, input map and save data.

const RATE := 22050
const SAVE_PATH := "user://parkour_mesh_save.json"

const LEVELS: Array[String] = [
	"res://scenes/level_1.tscn",
	"res://scenes/level_2.tscn",
	"res://scenes/level_3.tscn",
]
const LEVEL_NAMES: Array[String] = [
	"First Steps",
	"Neon Heights",
	"Core Runner",
]

# --- Run statistics -------------------------------------------------------
var current_level_index := 0
var level_time := 0.0
var level_deaths := 0
var level_coins := 0
var level_coin_total := 0

var run_total_time := 0.0
var run_total_deaths := 0
var run_total_coins := 0

# --- Save data ------------------------------------------------------------
var best_times := {}      # int level index -> float seconds
var best_combos := {}     # int level index -> int best shard streak
var unlocked_level := 0   # highest index available in level select

# --- Audio ----------------------------------------------------------------
var _sfx_streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input_map()
	_build_sounds()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _build_music_stream()
	_music_player.volume_db = -14.0
	add_child(_music_player)
	play_music()


# --- Input ----------------------------------------------------------------
func _setup_input_map() -> void:
	_bind_action("move_left", [KEY_A, KEY_LEFT])
	_bind_action("move_right", [KEY_D, KEY_RIGHT])
	_bind_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_bind_action("dash", [KEY_SHIFT, KEY_X])
	_bind_action("restart", [KEY_R])
	_bind_action("pause", [KEY_ESCAPE])


func _bind_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		# Idempotent: never add the same physical key twice (the actions
		# are also declared in project.godot's [input] section).
		var exists := false
		for old in InputMap.action_get_events(action):
			if old is InputEventKey and old.physical_keycode == k:
				exists = true
				break
		if not exists:
			InputMap.action_add_event(action, ev)


# --- Game flow ------------------------------------------------------------
func start_game(level_index: int = 0) -> void:
	run_total_time = 0.0
	run_total_deaths = 0
	run_total_coins = 0
	load_level(maxi(level_index, 0))


func load_level(index: int) -> void:
	current_level_index = clampi(index, 0, LEVELS.size() - 1)
	get_tree().paused = false
	_change_scene(LEVELS[current_level_index])


func restart_level() -> void:
	load_level(current_level_index)


func next_level() -> void:
	if current_level_index + 1 < LEVELS.size():
		load_level(current_level_index + 1)
	else:
		to_win_screen()


func to_main_menu() -> void:
	get_tree().paused = false
	_change_scene("res://scenes/main_menu.tscn")


func to_win_screen() -> void:
	get_tree().paused = false
	_change_scene("res://scenes/win_screen.tscn")


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)


func finish_level(time_seconds: float, coins: int, deaths: int,
		best_combo := 0) -> void:
	run_total_time += time_seconds
	run_total_deaths += deaths
	run_total_coins += coins
	unlocked_level = maxi(unlocked_level, mini(current_level_index + 1, LEVELS.size() - 1))
	var idx := current_level_index
	if not best_times.has(idx) or time_seconds < float(best_times[idx]):
		best_times[idx] = time_seconds
	if not best_combos.has(idx) or best_combo > int(best_combos[idx]):
		best_combos[idx] = maxi(best_combo, 0)
	save_progress()


# --- Save / load ----------------------------------------------------------
func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"best_times": best_times,
		"best_combos": best_combos,
		"unlocked_level": unlocked_level,
	}))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var bt = data.get("best_times", {})
	if typeof(bt) == TYPE_DICTIONARY:
		for k in bt:
			best_times[int(k)] = float(bt[k])
	var bc = data.get("best_combos", {})
	if typeof(bc) == TYPE_DICTIONARY:
		for k in bc:
			best_combos[int(k)] = maxi(int(bc[k]), 0)
	unlocked_level = clampi(int(data.get("unlocked_level", 0)), 0, LEVELS.size() - 1)


static func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%02d:%04.1f" % [minutes, seconds]


# --- SFX playback ---------------------------------------------------------
func play_sfx(sfx_name: String, volume_db: float = 0.0,
		pitch_jitter: float = 0.04, pitch_scale := 1.0) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	var player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_pool[0]
	player.stream = _sfx_streams[sfx_name]
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.1, pitch_scale * (1.0 + randf_range(-pitch_jitter, pitch_jitter)))
	player.play()


func play_music() -> void:
	if _music_player != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


# --- Procedural sound synthesis ------------------------------------------
func _make_buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _buf_to_wav(buf: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


## Adds one synthesized note into a float buffer.
## kind: "tri" (soft), "square", "saw", "sine", "noise"
## slide_to > 0 sweeps the frequency from freq to slide_to over the duration.
func _note(buf: PackedFloat32Array, start_s: float, dur_s: float, freq: float,
		vol: float = 0.4, kind: String = "tri", slide_to: float = 0.0,
		attack: float = 0.01, release: float = 0.35) -> void:
	var start_i := int(start_s * RATE)
	var n := int(dur_s * RATE)
	if n <= 0:
		return
	var phase := randf() * TAU
	var rel_start := 1.0 - release
	for j in n:
		var idx := start_i + j
		if idx >= buf.size():
			break
		var t := float(j) / RATE
		var prog := float(j) / float(n)
		var f := freq
		if slide_to > 0.0:
			f = lerpf(freq, slide_to, t / dur_s)
		phase += TAU * f / RATE
		var s := 0.0
		match kind:
			"sine":
				s = sin(phase)
			"square":
				s = signf(sin(phase)) * 0.6
			"saw":
				s = (fposmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.7
			"noise":
				s = randf() * 2.0 - 1.0
			_:
				s = (sin(phase) + 0.4 * sin(phase * 2.0)) * 0.7
		var env := 1.0
		if prog < attack:
			env = prog / attack
		elif prog > rel_start:
			env = maxf(0.0, 1.0 - (prog - rel_start) / release)
		buf[idx] += s * env * vol


func _build_sounds() -> void:
	var b: PackedFloat32Array

	b = _make_buf(0.18)
	_note(b, 0.0, 0.16, 330.0, 0.5, "tri", 640.0, 0.02, 0.5)
	_note(b, 0.0, 0.03, 200.0, 0.15, "noise")
	_sfx_streams["jump"] = _buf_to_wav(b)

	b = _make_buf(0.2)
	_note(b, 0.0, 0.17, 430.0, 0.45, "tri", 880.0, 0.02, 0.5)
	_sfx_streams["double_jump"] = _buf_to_wav(b)

	b = _make_buf(0.2)
	_note(b, 0.0, 0.16, 300.0, 0.42, "square", 740.0, 0.02, 0.55)
	_sfx_streams["wall_jump"] = _buf_to_wav(b)

	b = _make_buf(0.25)
	_note(b, 0.0, 0.16, 900.0, 0.3, "saw", 240.0, 0.01, 0.6)
	_note(b, 0.0, 0.12, 500.0, 0.22, "noise", 150.0, 0.005, 0.8)
	_sfx_streams["dash"] = _buf_to_wav(b)

	b = _make_buf(0.12)
	_note(b, 0.0, 0.09, 150.0, 0.4, "sine", 90.0, 0.01, 0.7)
	_sfx_streams["land"] = _buf_to_wav(b)

	b = _make_buf(0.3)
	_note(b, 0.0, 0.08, 987.77, 0.4, "sine", 0.0, 0.01, 0.4)
	_note(b, 0.07, 0.2, 1318.51, 0.45, "sine", 0.0, 0.01, 0.75)
	_sfx_streams["coin"] = _buf_to_wav(b)

	b = _make_buf(0.5)
	_note(b, 0.0, 0.42, 380.0, 0.5, "saw", 65.0, 0.01, 0.5)
	_note(b, 0.05, 0.3, 220.0, 0.2, "noise", 70.0, 0.01, 0.8)
	_sfx_streams["death"] = _buf_to_wav(b)

	b = _make_buf(0.28)
	_note(b, 0.0, 0.22, 190.0, 0.45, "tri", 950.0, 0.02, 0.5)
	_sfx_streams["spring"] = _buf_to_wav(b)

	b = _make_buf(0.5)
	_note(b, 0.0, 0.12, 784.0, 0.35, "sine", 0.0, 0.01, 0.5)
	_note(b, 0.12, 0.34, 1174.66, 0.38, "sine", 0.0, 0.01, 0.7)
	_sfx_streams["checkpoint"] = _buf_to_wav(b)

	b = _make_buf(0.85)
	var seq := [523.25, 659.26, 784.0, 1046.5]
	for i in seq.size():
		_note(b, i * 0.13, 0.24, seq[i], 0.4, "tri", 0.0, 0.01, 0.6)
	_note(b, 0.52, 0.3, 1318.5, 0.42, "tri", 0.0, 0.01, 0.7)
	_sfx_streams["win"] = _buf_to_wav(b)

	b = _make_buf(0.3)
	_note(b, 0.0, 0.24, 160.0, 0.3, "saw", 70.0, 0.01, 0.6)
	_note(b, 0.0, 0.2, 400.0, 0.12, "noise", 100.0, 0.01, 0.8)
	_sfx_streams["crumble"] = _buf_to_wav(b)

	b = _make_buf(0.08)
	_note(b, 0.0, 0.06, 700.0, 0.22, "square", 900.0, 0.01, 0.6)
	_sfx_streams["click"] = _buf_to_wav(b)

	b = _make_buf(0.4)
	_note(b, 0.0, 0.35, 520.0, 0.35, "tri", 1040.0, 0.01, 0.7)
	_sfx_streams["goal"] = _buf_to_wav(b)


func _build_music_stream() -> AudioStreamWAV:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 4
	# The buffer must be EXACTLY the musical length. Any padding (the old
	# +0.4s tail) creates a silent gap and an audible hiccup at the loop
	# point; every note envelope below decays to zero inside its own
	# duration, so wrapping at the exact bar boundary is click-free.
	var total := bar * bars
	var buf := _make_buf(total)

	# Chord roots per bar: Am - F - C - G (A2, F2, C3, G2)
	var roots := [110.0, 87.31, 130.81, 98.0]
	# Pentatonic-ish arpeggio intervals above each root (semitones).
	var arps := [
		[0, 12, 15, 19, 24, 19, 15, 12],
		[0, 12, 16, 21, 24, 21, 16, 12],
		[0, 12, 16, 19, 24, 19, 16, 12],
		[0, 12, 14, 19, 22, 19, 14, 12],
	]

	for bar_i in bars:
		var t0 := bar_i * bar
		var root: float = roots[bar_i]
		# Bass on beats 1 and 3.
		_note(buf, t0, beat * 1.9, root, 0.30, "square", 0.0, 0.02, 0.4)
		_note(buf, t0 + beat * 2.0, beat * 1.9, root, 0.26, "square", 0.0, 0.02, 0.4)
		# Eighth-note arpeggio.
		var pattern: Array = arps[bar_i]
		for step in 8:
			var semi: int = pattern[step]
			var f := root * pow(2.0, float(semi) / 12.0) * 2.0
			_note(buf, t0 + step * beat * 0.5, beat * 0.48, f, 0.16, "tri", 0.0, 0.01, 0.5)
		# Soft hat ticks on off-beats.
		for step in 4:
			_note(buf, t0 + (step * 2 + 1) * beat * 0.5, 0.05, 8000.0, 0.045, "noise")

	return _buf_to_wav(buf, true)
