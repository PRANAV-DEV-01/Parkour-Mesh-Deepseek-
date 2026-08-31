class_name LevelAdapter
extends RefCounted
## Level Adapter - applies a SINGLE, subtle, deterministic adaptation to a
## level, then logs the change to user://level_adaptations.log.
##
## Deceit AVOIDED: every adaptation is safe and non-breaking.
##   * High deaths (>=5) -> an EASE (help) adaptation is applied.
##   * Low deaths (<=1)  -> a HAZARD (challenge) adaptation is applied.
##
## Only one adaptation is applied per level per session; nothing stacks.


const LOG_PATH := "user://level_adaptations.log"

const HELP_DASH_COOLDOWN := "reduce_dash_cooldown"
const HELP_CRUMBLE_FIX := "stabilize_crumble"
const HELP_SAFETY_PLATFORM := "add_safety_platform"
const HAZARD_SPIKE_EXTEND := "extend_spike"
const HAZARD_DASH_PENALTY := "raise_dash_cooldown"

# Track which level/adaptation we already applied this run so re-entries
# (fast restarts) cannot stack adaptations.
static var applied_this_session := {}


static func adapt(level: Node2D) -> void:
	var level_index: int = Globals.current_level_index
	if applied_this_session.has(level_index):
		return
	applied_this_session[level_index] = true

	var deaths := PlayerMemory.get_death_count(level_index)
	var adaptation := ""
	var reason := ""
	if deaths >= 5:
		var choice := (level_index * 7 + deaths) % 3
		match choice:
			0:
				adaptation = HELP_DASH_COOLDOWN
				reason = "many deaths: reduce dash cooldown support"
				_apply_dash_cooldown(level, -0.1)
			1:
				adaptation = HELP_CRUMBLE_FIX
				reason = "many deaths: stabilize a crumble platform"
				_apply_stabilize_crumble(level)
			_:
				adaptation = HELP_SAFETY_PLATFORM
				reason = "many deaths: add safety platform under a crumble"
				_apply_safety_platform(level)
	elif deaths <= 1:
		# Player is doing great - add a gentle challenge, still safe.
		var choice := (level_index * 3 + deaths) % 2
		match choice:
			0:
				adaptation = HAZARD_SPIKE_EXTEND
				reason = "few deaths: extend an existing spike row by one tooth"
				_apply_extend_spike(level)
			_:
				adaptation = HAZARD_DASH_PENALTY
				reason = "few deaths: nudge dash cooldown higher (inverse effect)"
				_apply_dash_cooldown(level, 0.05)
	else:
		return

	_log(level_index, deaths, adaptation, reason)
	print("[LevelAdapter] level ", level_index, " deaths=", deaths,
			" adaptation=", adaptation)


# ------------------------------------------------------------ helpers ----
static func _find_crumble(level: Node2D) -> Array:
	var out := []
	for n in level.get_tree().get_nodes_in_group("accent"):
		if n is CrumblePlatform:
			out.append(n)
	return out


static func _find_spike(level: Node2D) -> Array:
	var out := []
	for n in level.get_tree().get_nodes_in_group("accent"):
		if n is Spike:
			out.append(n)
	return out


static func _apply_dash_cooldown(level: Node2D, delta: float) -> void:
	var player := level.get_node_or_null("Player")
	if player is Player:
		player.set_dash_cooldown_offset(delta)


static func _apply_stabilize_crumble(level: Node2D) -> void:
	var crumbles := _find_crumble(level)
	if crumbles.is_empty():
		# Nothing to stabilize - fall back to a pure support buff instead.
		_apply_dash_cooldown(level, -0.1)
		return
	# Prefer a crumble not under the spawn point for safety.
	var best: CrumblePlatform = crumbles[0]
	for c in crumbles:
		if absf(c.global_position.x - level.player.global_position.x) > 140.0:
			best = c
			break
	best.stabilize()


static func _apply_safety_platform(level: Node2D) -> void:
	var crumbles := _find_crumble(level)
	if crumbles.is_empty():
		_apply_dash_cooldown(level, -0.1)
		return
	var c: CrumblePlatform = crumbles[0]
	Platform.spawn_visual_static(level, c.global_position + Vector2(0, 90.0),
			Vector2(c.size.x, 24.0))


static func _apply_extend_spike(level: Node2D) -> void:
	var spikes := _find_spike(level)
	if spikes.is_empty():
		# No spike row to extend - grant the dash cooldown inverse instead.
		_apply_dash_cooldown(level, 0.05)
		return
	var spike: Spike = spikes[0]
	spike.extend_row(1)


# ---------------------------------------------------------------- log ----
static func _log(level_index: int, deaths: int, adaptation: String,
		reason: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		# Might not exist yet - create it.
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f == null:
			return
	else:
		f.seek_end()
	var ts := Time.get_datetime_string_from_system()
	f.store_string("%s | level=%d | deaths=%d | adaptation=%s | reason=%s\n" % [
		ts, level_index, deaths, adaptation, reason,
	])
	f.flush()
