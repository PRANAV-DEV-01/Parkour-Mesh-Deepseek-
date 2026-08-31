extends Node
## Player Memory: persistent, behavior-aware save data for the "Living World"
## system. Tracks deaths, best times, shards, playstyle, ghost best-runs and a
## detailed death journal, persisted as JSON in user://memory.save.
##
## This is intentionally SEPARATE from Globals' own save file (stars/shards/
## unlocks). It is registered as an autoload in project.godot.


const SAVE_PATH := "user://memory.save"

var memory := {
	"deaths_per_level": {},
	"best_time_per_level": {},
	"shards_collected_per_level": {},
	"playstyle_score": {
		"aggressive": 0.0,
		"cautious": 0.0,
		"dash_usage": 0,
		"jump_delay_sum": 0.0,
		"jump_count": 0,
	},
	"total_playtime": 0.0,
	"last_session_date": "",
	"ghost_beaten_count": 0,
	"death_journal": [],
	"best_runs": {},
}

# Deaths recorded this session (initialised with the persisted value so the
# daily popup reflects the full previous-day story on first boot).
var session_deaths := 0

var _session_start_msec := 0
var _session_ended := false

var _total_session_play_delta := 0.0


func _ready() -> void:
	print("[PlayerMemory] ready - loading memory")
	load_memory()


# ------------------------------------------------------------------ util ---
func get_today_string() -> String:
	return Time.get_date_string_from_system()


func get_yesterday_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	var d := Time.get_unix_time_from_datetime_dict({
		"year": dt["year"], "month": dt["month"], "day": dt["day"],
		"hour": 0, "minute": 0, "second": 0,
	})
	d -= 86400.0
	var y := Time.get_datetime_dict_from_unix_time(d)
	return "%04d-%02d-%02d" % [y["year"], y["month"], y["day"]]


static func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _as_int(v: Variant) -> int:
	return v if typeof(v) == TYPE_INT else 0


static func _as_float(v: Variant) -> float:
	return v if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else 0.0


static func _as_string(v: Variant) -> String:
	if typeof(v) == TYPE_STRING:
		return v
	return str(v)


# ----------------------------------------------------------------- save -----
func save_memory() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		print("[PlayerMemory] WARN: could not open save for writing: ", SAVE_PATH)
		return
	f.store_string(JSON.stringify(memory))
	print("[PlayerMemory] saved memory (deaths_per_level=",
			memory["deaths_per_level"], ")")


func load_memory() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[PlayerMemory] no save file - using defaults")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		print("[PlayerMemory] WARN: could not read save - using defaults")
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		print("[PlayerMemory] WARN: malformed save - using defaults")
		return
	_apply_parsed(data)


func _apply_parsed(d: Dictionary) -> void:
	var deaths := _as_dict(d.get("deaths_per_level"))
	for k in deaths:
		memory["deaths_per_level"][int(k)] = _as_int(deaths[k])

	var times := _as_dict(d.get("best_time_per_level"))
	for k in times:
		memory["best_time_per_level"][int(k)] = _as_float(times[k])

	var shards := _as_dict(d.get("shards_collected_per_level"))
	for k in shards:
		memory["shards_collected_per_level"][int(k)] = _as_int(shards[k])

	var style := _as_dict(_as_dict(d.get("playstyle_score")) if d.has("playstyle_score") else {})
	var base := _as_dict(memory["playstyle_score"])
	for key in base:
		if style.has(key):
			base[key] = style[key]
	memory["playstyle_score"] = base

	memory["total_playtime"] = _as_float(d.get("total_playtime"))
	memory["last_session_date"] = _as_string(d.get("last_session_date"))
	memory["ghost_beaten_count"] = maxi(_as_int(d.get("ghost_beaten_count")), 0)

	var journal: Variant = d.get("death_journal", [])
	if typeof(journal) == TYPE_ARRAY:
		memory["death_journal"] = journal

	var runs := _as_dict(d.get("best_runs"))
	for k in runs:
		var r := _as_dict(runs[k])
		if r.is_empty():
			continue
		var frames: Variant = r.get("frames", [])
		if typeof(frames) == TYPE_ARRAY and frames.size() > 0:
			memory["best_runs"][int(k)] = {
				"duration": _as_float(r.get("duration")),
				"frames": frames,
			}

	session_deaths = 0
	for k in memory["deaths_per_level"]:
		session_deaths += int(memory["deaths_per_level"][k])


# --------------------------------------------------------------- helpers ----
func get_death_count(level_index: int) -> int:
	return _as_int(memory["deaths_per_level"].get(level_index, 0))


func get_best_time(level_index: int) -> float:
	return _as_float(memory["best_time_per_level"].get(level_index, 0.0))


func get_shards(level_index: int) -> int:
	return _as_int(memory["shards_collected_per_level"].get(level_index, 0))


func get_total_deaths() -> int:
	var t := 0
	for k in memory["deaths_per_level"]:
		t += _as_int(memory["deaths_per_level"][k])
	return t


# ------------------------------------------------------------- recording ----
func record_death(level_index: int, time_seconds: float, position: Vector2) -> void:
	var cur := get_death_count(level_index)
	memory["deaths_per_level"][level_index] = cur + 1
	session_deaths += 1
	memory["death_journal"].append({
		"level": level_index,
		"time": time_seconds,
		"date": get_today_string(),
		"position": {"x": position.x, "y": position.y},
	})
	save_memory()


func record_best_time(level_index: int, time_seconds: float) -> bool:
	var prev := get_best_time(level_index)
	if prev <= 0.0 or time_seconds < prev:
		memory["best_time_per_level"][level_index] = time_seconds
		save_memory()
		return true
	return false


func record_shards(level_index: int, shard_count: int) -> void:
	var cur := _as_int(memory["shards_collected_per_level"].get(level_index, 0))
	if shard_count > cur:
		memory["shards_collected_per_level"][level_index] = shard_count
		save_memory()


func record_playstyle_event(event_type: String, value: Variant) -> void:
	var style: Dictionary = memory["playstyle_score"]
	match event_type:
		"dash":
			style["dash_usage"] = _as_int(style["dash_usage"]) + 1
		"jump_delay":
			style["jump_delay_sum"] = _as_float(style["jump_delay_sum"]) + _as_float(value)
			style["jump_count"] = _as_int(style["jump_count"]) + 1
		"aggressive":
			style["aggressive"] = _as_float(style["aggressive"]) + _as_float(value)
		"cautious":
			style["cautious"] = _as_float(style["cautious"]) + _as_float(value)
	save_memory()


func record_session_start() -> void:
	var today := get_today_string()
	if memory["last_session_date"] != today:
		print("[PlayerMemory] new session day (", memory["last_session_date"],
				" -> ", today, ")")
		memory["last_session_date"] = today
		save_memory()
	_session_start_msec = Time.get_ticks_msec()


func record_session_end(delta_time: float) -> void:
	memory["total_playtime"] = _as_float(memory["total_playtime"]) + maxf(delta_time, 0.0)
	save_memory()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _session_ended:
			return
		_session_ended = true
		if _session_start_msec > 0:
			var dur := (Time.get_ticks_msec() - _session_start_msec) / 1000.0
			record_session_end(dur)
		else:
			record_session_end(_total_session_play_delta)


func record_ghost_beaten() -> void:
	memory["ghost_beaten_count"] = maxi(_as_int(memory["ghost_beaten_count"]) + 1, 0)
	save_memory()


# -------------------------------------------------------- ghost runs --------
func save_best_run(level_index: int, duration: float, frames: Array) -> void:
	var prev = memory["best_time_per_level"].get(level_index, 0.0)
	if prev > 0.0 and duration >= float(prev):
		return
	if prev <= 0.0 or duration < float(prev):
		memory["best_time_per_level"][level_index] = duration
	memory["best_runs"][level_index] = {
		"duration": duration,
		"frames": frames,
	}
	save_memory()
	print("[PlayerMemory] saved best run for level ", level_index,
			" duration=", duration)


func get_best_run(level_index: int) -> Dictionary:
	return _as_dict(memory["best_runs"].get(level_index))


# --------------------------------------------------------- session/death ----
func get_deaths_on_date(date_str: String) -> int:
	var n := 0
	for e in memory["death_journal"]:
		if typeof(e) == TYPE_DICTIONARY and _as_string(e.get("date")) == date_str:
			n += 1
	return n
