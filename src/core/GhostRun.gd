extends Node2D
## Ghost Run system - records the player's best run per level and replays it
## as a semi-transparent 'memory ghost'. The ghost is purely visual (no
## physics, no collisions, no pickups), runs alongside the player, and a
## special cue fires when the player beats its stored time.
##
## The level manager (scripts/level.gd) instantiates one of these per level.

const SAMPLE_INTERVAL := 0.05   # seconds between recorded frames
const PLAYSTYLE_FLUSH := 4.0    # seconds between playstyle score flushes

var _level: Node2D
var _player: Player
var _recording := false
var _sample_timer := 0.0
var _rec_frames: Array = []

var _ghost: _Ghost = null
var _ghost_duration := 0.0
var _ghost_frames: Array = []
var _ghost_idx := 0
var _ghost_t := 0.0

# Playstyle accumulation (flushed periodically to PlayerMemory).
var _dash_presses := 0
var _jump_presses := 0
var _jump_delay_sum := 0.0
var _aggressive := 0.0
var _cautious := 0.0
var _samples := 0
var _last_jump_t := -1.0
var _playstyle_timer := 0.0

func setup(level: Node2D) -> void:
	_level = level
	_player = level.get_node_or_null("Player") as Player
	if _player == null:
		return

	# Replay path: if a best run exists, drop in a visual ghost.
	_load_best_run()
	if not _ghost_frames.is_empty():
		_spawn_ghost()

	# Always record the current session run so a new best can be saved.
	_recording = true
	_rec_frames.clear()
	_sample_timer = 0.0


func _load_best_run() -> void:
	var level_index: int = Globals.current_level_index
	var run := PlayerMemory.get_best_run(level_index)
	if run.is_empty():
		return
	_ghost_duration = run.get("duration", 0.0)
	var frames = run.get("frames", [])
	if typeof(frames) == TYPE_ARRAY and frames.size() > 0:
		_ghost_frames = frames


func _spawn_ghost() -> void:
	_ghost = _Ghost.new()
	_ghost.modulate = Color(0.45, 0.95, 1.0, 0.35)
	add_child(_ghost)
	_ghost_idx = 0
	_ghost_t = 0.0
	if not _ghost_frames.is_empty():
		var f: Dictionary = _ghost_frames[0]
		_ghost.position = _v(f.get("position"))


func _physics_process(delta: float) -> void:
	if _player == null or _level == null or _level.completed:
		return

	if _recording:
		_sample_timer += delta
		if _sample_timer >= SAMPLE_INTERVAL:
			_sample_timer = 0.0
			_record_frame()

	if _ghost != null and not _ghost_frames.is_empty():
		_ghost_t += delta
		_advance_ghost()


func _record_frame() -> void:
	var p = _player
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("dash")
	_rec_frames.append({
		"t": _sample_cursor(),
		"position": {"x": p.global_position.x, "y": p.global_position.y},
		"velocity": {"x": p.velocity.x, "y": p.velocity.y},
	})

	# Playstyle accumulation.
	_samples += 1
	_aggressive += clampf(absf(p.velocity.x) / 340.0, 0.0, 1.0)
	_cautious += 1.0 if (p.is_on_floor() and absf(p.velocity.x) < 40.0) else 0.0
	if jump:
		_jump_presses += 1
		var now := _sample_cursor()
		if _last_jump_t >= 0.0:
			_jump_delay_sum += maxf(0.0, now - _last_jump_t)
		_last_jump_t = now
	if dash:
		_dash_presses += 1

	_playstyle_timer += SAMPLE_INTERVAL
	if _playstyle_timer >= PLAYSTYLE_FLUSH:
		_playstyle_timer = 0.0
		_flush_playstyle()


func _sample_cursor() -> float:
	# Approximate run cursor from the elapsed level time.
	return _level.hud.get_elapsed() if _level and _level.hud else 0.0


static func _v(v) -> Vector2:
	if typeof(v) == TYPE_DICTIONARY:
		return Vector2(v.get("x", 0.0), v.get("y", 0.0))
	return Vector2.ZERO


func _advance_ghost() -> void:
	if _ghost_idx >= _ghost_frames.size() - 1:
		return
	while _ghost_idx < _ghost_frames.size() - 1:
		var cur: Dictionary = _ghost_frames[_ghost_idx]
		var nxt: Dictionary = _ghost_frames[_ghost_idx + 1]
		var t_cur: float = cur.get("t", 0.0)
		var t_nxt: float = nxt.get("t", t_cur + SAMPLE_INTERVAL)
		if _ghost_t >= t_nxt:
			_ghost_idx += 1
			continue
		var k := clampf((_ghost_t - t_cur) / maxf(t_nxt - t_cur, 0.0001), 0.0, 1.0)
		_ghost.position = _v(cur.get("position")).lerp(_v(nxt.get("position")), k)
		return
	# End of recording.
	var last: Dictionary = _ghost_frames[_ghost_frames.size() - 1]
	_ghost.position = _v(last.get("position"))


## Called by the level when the player reaches the goal. If this run beats the
## stored ghost time, the run is saved as the new best, a cue plays, and the
## ghost-beaten stat increments. Returns true if the ghost was beaten.
func on_finish() -> bool:
	_recording = false
	_flush_playstyle()

	var level_index: int = Globals.current_level_index
	var dur := _sample_cursor()
	var pre_existing: bool = _ghost_duration > 0.0

	var beat := false
	if not _ghost_frames.is_empty():
		beat = dur < _ghost_duration

	var prev_best := PlayerMemory.get_best_time(level_index)
	if prev_best <= 0.0 or dur < prev_best:
		PlayerMemory.save_best_run(level_index, dur, _rec_frames)
		if beat or prev_best <= 0.0:
			PlayerMemory.record_ghost_beaten()
			beat = true
			if pre_existing:
				Globals.play_sfx("win")
				if _level and _level.hud:
					_level.hud.show_toast_message("YOU BEAT YOUR GHOST!")

	return beat


func _flush_playstyle() -> void:
	if _samples <= 0:
		return
	PlayerMemory.record_playstyle_event("dash", null)
	PlayerMemory.record_playstyle_event("aggressive", _aggressive / float(_samples))
	PlayerMemory.record_playstyle_event("cautious", _cautious / float(_samples))
	PlayerMemory.record_playstyle_event("jump_delay",
			_jump_delay_sum / float(maxi(_jump_presses, 1)))
	# Reset per-sample accumulators but keep cumulative counters in memory.
	_aggressive = 0.0
	_cautious = 0.0
	_samples = 0
	_jump_presses = 0
	_jump_delay_sum = 0.0
	_last_jump_t = -1.0


## A simple semi-transparent figure that replays a recorded path. No physics,
## no collision, purely visual.
class _Ghost:
	extends Node2D

	var _body: Polygon2D
	var _glow: Polygon2D
	var _t := 0.0

	func _init() -> void:
		z_index = -5
		_build()

	func _build() -> void:
		var silhouette := PackedVector2Array([
			Vector2(-11, -24), Vector2(11, -24),
			Vector2(11, 20), Vector2(-11, 20),
		])
		_glow = Polygon2D.new()
		_glow.polygon = silhouette
		_glow.scale = Vector2(1.16, 1.16)
		_glow.color = Color(0.4, 0.9, 1.0, 0.18)
		add_child(_glow)
		_body = Polygon2D.new()
		_body.polygon = silhouette
		_body.color = Color(0.5, 0.95, 1.0, 0.5)
		add_child(_body)

	func _process(delta: float) -> void:
		_t += delta
		var pulse := 0.85 + 0.15 * sin(_t * 3.0)
		_body.color.a = 0.4 * pulse
