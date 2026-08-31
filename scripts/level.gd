class_name GameLevel
extends Node2D
## Per-level controller: tracks stats, deaths/respawns, checkpoints,
## coin collection + combo streaks, goal completion and restart flow.

@export var display_name := "LEVEL 1"
@export var accent_color := Color("#22d3ee")
@export var camera_bounds := Rect2(-240, -900, 3800, 1700)
@export var kill_y := 1100.0

const COMBO_WINDOW := 3.0   # seconds between shards to keep the streak
const GHOST_RUN_SCRIPT := preload("res://src/core/GhostRun.gd")

var player: Player
var hud: GameHUD
var ghost: Node2D

var spawn_point := Vector2.ZERO
var checkpoint_pos := Vector2.ZERO
var current_checkpoint: Checkpoint = null

var level_coins := 0
var level_deaths := 0
var coin_total := 0
var completed := false

# Respawn pipeline: deaths are counted, never swallowed. A single async
# worker drains the queue so overlapping deaths can't soft-lock the game.
var _deaths_pending := 0
var _respawn_active := false

# Shard combo streak.
var combo := 0
var combo_timer := 0.0
var best_combo := 0

func _ready() -> void:
	add_to_group("level")
	Globals.load_progress()

	var bg := BackgroundGrid.new()
	add_child(bg)

	player = get_node("Player") as Player
	hud = get_node("HUD") as GameHUD

	spawn_point = player.global_position
	checkpoint_pos = spawn_point

	player.died.connect(_on_player_died)

	coin_total = get_tree().get_nodes_in_group("shard").size()
	for n in get_tree().get_nodes_in_group("accent"):
		n.set_accent(accent_color)

	player.setup_camera(camera_bounds)
	hud.setup(player, display_name, coin_total, accent_color)
	hud.restart_requested.connect(_do_restart)
	hud.next_level_requested.connect(_on_next_level)
	hud.menu_requested.connect(_go_menu)

	if DisplayServer.is_touchscreen_available():
		var tc := TouchControls.new()
		add_child(tc)
		tc.pause_pressed.connect(hud.request_pause)

	# Living World: apply a subtle level adaptation and spin up the ghost run.
	LevelAdapter.adapt(self)
	ghost = GHOST_RUN_SCRIPT.new()
	add_child(ghost)
	ghost.setup(self)


func _process(delta: float) -> void:
	if completed:
		return
	if combo > 0 and combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_break_combo()


func _physics_process(_delta: float) -> void:
	if not completed and player.global_position.y > kill_y:
		player.die()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not completed and not get_tree().paused:
		_do_restart()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ events
func on_coin_collected() -> void:
	level_coins += 1
	combo += 1
	combo_timer = COMBO_WINDOW
	best_combo = maxi(best_combo, combo)
	hud.set_coins(level_coins)
	# Pitch climbs with the streak - classic juice.
	var pitch := 1.0 + 0.07 * minf(float(combo - 1), 10.0)
	Globals.play_sfx("coin", 0.0, 0.03, pitch)
	hud.show_combo(combo)
	if coin_total > 0 and level_coins >= coin_total:
		hud.show_toast_message("ALL SHARDS COLLECTED!")
		Globals.play_sfx("checkpoint")


func break_combo() -> void:
	if combo > 1:
		hud.flash_combo_lost(combo)
	_break_combo()


func _break_combo() -> void:
	combo = 0
	combo_timer = 0.0
	hud.hide_combo()


func register_checkpoint(cp: Checkpoint) -> void:
	if current_checkpoint != null and current_checkpoint != cp:
		current_checkpoint.deactivate()
	current_checkpoint = cp
	checkpoint_pos = cp.spawn_position()


func on_goal_reached() -> void:
	if completed:
		return
	completed = true
	hud.timing = false
	var is_last := Globals.current_level_index >= Globals.LEVELS.size() - 1
	Globals.finish_level(hud.get_elapsed(), level_coins, level_deaths,
			best_combo)
	PlayerMemory.record_shards(Globals.current_level_index, level_coins)
	if ghost != null:
		ghost.on_finish()
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree():
		return
	Globals.play_sfx("win")
	hud.show_complete(level_coins, level_deaths, is_last, best_combo)


# ------------------------------------------------------------------ death / respawn
func _on_player_died() -> void:
	if completed:
		return
	level_deaths += 1
	hud.set_deaths(level_deaths)
	PlayerMemory.record_death(Globals.current_level_index,
			hud.get_elapsed(), player.global_position)
	break_combo()
	_deaths_pending += 1
	if not _respawn_active:
		_run_respawn_worker()


## Single async worker that drains pending deaths. A death that lands
## DURING a respawn cycle increments the queue instead of being ignored,
## so the player can never end up stuck dead.
func _run_respawn_worker() -> void:
	_respawn_active = true
	while _deaths_pending > 0 and not completed:
		_deaths_pending = 0   # collapse simultaneous deaths into one cycle
		await get_tree().create_timer(0.55).timeout
		if not is_inside_tree():
			return
		await hud.fade_out(0.16)
		if not is_inside_tree():
			return
		player.respawn(checkpoint_pos)
		hud.fade_in(0.32)
	_respawn_active = false


# ------------------------------------------------------------------ flow
func _do_restart() -> void:
	completed = true
	get_tree().paused = false
	await hud.fade_out(0.22)
	Globals.restart_level()


func _on_next_level() -> void:
	completed = true
	Globals.next_level()


func _go_menu() -> void:
	get_tree().paused = false
	await hud.fade_out(0.22)
	Globals.to_main_menu()
