class_name Player
extends CharacterBody2D
## Parkour player: run, jump, double jump, coyote time, jump buffering,
## wall slide, wall jump, dash, squash & stretch and particle FX.
## Visuals: animated legs, flowing scarf, neon outline glow, blinking eyes,
## pulsing energy core and idle breathing.

signal died

const SPEED := 340.0
const ACCEL := 2800.0
const AIR_ACCEL := 2100.0
const FRICTION := 3400.0
const AIR_FRICTION := 1000.0
const GRAVITY_UP := 1500.0
const GRAVITY_DOWN := 2200.0
const MAX_FALL := 1150.0
const JUMP_VELOCITY := -600.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.13
const WALL_SLIDE_SPEED := 140.0
const WALL_JUMP_X := 440.0
const WALL_JUMP_Y := -560.0
const DASH_SPEED := 800.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.4

var active := true            # false during level-complete / death sequences
var control_enabled := true   # false while dead

var _coyote := 0.0
var _jump_buffer := 0.0
var _jumps_used := 0
var _max_jumps := 2
var _can_dash := true
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_cooldown_offset := 0.0   # +/- applied by the Living World adapter
var _dash_dir := Vector2.RIGHT
var _facing := 1.0
var _was_on_floor := false
var _fall_peak := 0.0
var _cut_jump := false
var _wall_lock := 0.0        # brief input lockout after a wall jump so the
                             # kick can't be eaten by held into-wall input
var _is_dead := false
var _spawn_shield := 0.0     # brief post-respawn immunity (blocks stale hazard hits)
var _collision_shape: CollisionShape2D
var _cam_tween: Tween

var vis: Node2D
var squash_node: Node2D
var body_poly: Polygon2D
var eye_l: Polygon2D
var eye_r: Polygon2D
var pupil_l: Polygon2D
var pupil_r: Polygon2D
var antenna: Node2D
var cam: Camera2D
var dust: CPUParticles2D
var trail: CPUParticles2D
var burst: CPUParticles2D

var _trauma := 0.0
var _squash_tween: Tween

# Character animation state.
var leg_l: Line2D
var leg_r: Line2D
var scarf: Line2D
var core_glow: Polygon2D
var core_dot: Polygon2D
var bulb_glow: Polygon2D
var bulb: Polygon2D
var _anim_time := 0.0
var _run_phase := 0.0
var _foot_l := Vector2(-5.0, 26.0)
var _foot_r := Vector2(5.0, 26.0)
var _scarf_pts: PackedVector2Array
var _blink_timer := 2.5
var _bob_y := 0.0

const HIP_L := Vector2(-6.5, 11.0)
const HIP_R := Vector2(6.5, 11.0)
const FOOT_Y := 26.0
const SCARF_SEGS := 9
const SCARF_SEG_LEN := 6.5

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	safe_margin = 0.5
	floor_snap_length = 14.0   # stay glued to descending moving platforms
	add_to_group("player")
	_build_collision()
	_build_visuals()
	_build_particles()
	_build_camera()


# --- Construction ---------------------------------------------------------
func _build_collision() -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 54)
	cs.shape = shape
	add_child(cs)
	_collision_shape = cs


func _build_visuals() -> void:
	vis = Node2D.new()
	vis.name = "Vis"
	add_child(vis)

	squash_node = Node2D.new()
	squash_node.name = "Squash"
	vis.add_child(squash_node)

	# Neon outline glow (two soft halos behind the whole figure).
	var w := 16.0
	var h_top := 25.0
	var h_bot := 15.0
	var r := 6.0
	var silhouette := PackedVector2Array([
		Vector2(-w + r, -h_top), Vector2(w - r, -h_top),
		Vector2(w, -h_top + r), Vector2(w, h_bot - r),
		Vector2(w - r, h_bot), Vector2(-w + r, h_bot),
		Vector2(-w, h_bot - r), Vector2(-w, -h_top + r),
	])
	for halo in [[1.30, 0.10], [1.14, 0.28]]:
		var glow_poly := Polygon2D.new()
		glow_poly.polygon = silhouette
		glow_poly.color = Color(0.36, 0.83, 0.98, halo[1])
		glow_poly.scale = Vector2(halo[0], halo[0])
		squash_node.add_child(glow_poly)

	# Rounded octagon body with a subtle vertical gradient.
	body_poly = Polygon2D.new()
	body_poly.polygon = silhouette
	body_poly.vertex_colors = PackedColorArray([
		Color("#7dd3fc"), Color("#38bdf8"), Color("#22d3ee"),
		Color("#0e7490"), Color("#155e75"), Color("#155e75"),
		Color("#0e7490"), Color("#22d3ee"),
	])
	squash_node.add_child(body_poly)

	# Chest energy core.
	core_glow = Polygon2D.new()
	core_glow.polygon = _diamond_points(Vector2.ZERO, 9.0)
	core_glow.position = Vector2(0, -2)
	core_glow.color = Color(0.95, 0.42, 0.71, 0.22)
	squash_node.add_child(core_glow)
	core_dot = Polygon2D.new()
	core_dot.polygon = _diamond_points(Vector2.ZERO, 3.6)
	core_dot.position = Vector2(0, -2)
	core_dot.color = Color("#fda4af")
	squash_node.add_child(core_dot)

	antenna = Node2D.new()
	antenna.position = Vector2(0, -h_top)
	squash_node.add_child(antenna)
	var stem := Line2D.new()
	stem.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -10)])
	stem.width = 3.0
	stem.default_color = Color("#a5f3fc")
	antenna.add_child(stem)
	bulb_glow = Polygon2D.new()
	bulb_glow.polygon = _diamond_points(Vector2(0, -14), 11.0)
	bulb_glow.color = Color(0.95, 0.42, 0.71, 0.25)
	antenna.add_child(bulb_glow)
	bulb = Polygon2D.new()
	bulb.polygon = _diamond_points(Vector2(0, -14), 5.0)
	bulb.color = Color("#f472b6")
	antenna.add_child(bulb)

	eye_l = _make_eye(Vector2(-6.5, -8))
	eye_r = _make_eye(Vector2(6.5, -8))
	squash_node.add_child(eye_l)
	squash_node.add_child(eye_r)
	pupil_l = eye_l.get_child(0)
	pupil_r = eye_r.get_child(0)

	# Little legs (drawn behind the body so hips stay hidden).
	leg_l = _make_leg(HIP_L)
	leg_r = _make_leg(HIP_R)

	# Flowing scarf anchored at the neck (child of the body root so it does
	# not mirror with facing; simulated in world-space below).
	scarf = Line2D.new()
	scarf.width = 9.0
	scarf.default_color = Color("#f472b6")
	scarf.joint_mode = Line2D.LINE_JOINT_ROUND
	scarf.begin_cap_mode = Line2D.LINE_CAP_ROUND
	scarf.end_cap_mode = Line2D.LINE_CAP_ROUND
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.62))
	taper.add_point(Vector2(0.72, 0.92))
	taper.add_point(Vector2(1.0, 0.06))
	scarf.width_curve = taper
	_scarf_pts = PackedVector2Array()
	for i in SCARF_SEGS:
		_scarf_pts.append(Vector2(0, -18 + i * SCARF_SEG_LEN))
	scarf.points = _scarf_pts
	add_child(scarf)


func _make_leg(hip: Vector2) -> Line2D:
	var leg := Line2D.new()
	leg.width = 7.0
	leg.default_color = Color("#0c4a6e")
	leg.joint_mode = Line2D.LINE_JOINT_ROUND
	leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
	leg.end_cap_mode = Line2D.LINE_CAP_ROUND
	leg.points = PackedVector2Array([hip, Vector2(signf(hip.x) * 5.0, FOOT_Y)])
	squash_node.add_child(leg)
	return leg


static func _diamond_points(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.62, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.62, 0),
	])


func _make_eye(pos: Vector2) -> Polygon2D:
	var eye := Polygon2D.new()
	eye.position = pos
	eye.color = Color(0.05, 0.09, 0.16)
	eye.polygon = PackedVector2Array([
		Vector2(-4.5, -4.5), Vector2(4.5, -4.5),
		Vector2(4.5, 3.5), Vector2(0, 6.5), Vector2(-4.5, 3.5),
	])
	var pupil := Polygon2D.new()
	pupil.color = Color("#e0fbff")
	pupil.polygon = PackedVector2Array([
		Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2),
	])
	eye.add_child(pupil)
	return eye


func _build_particles() -> void:
	dust = CPUParticles2D.new()
	dust.amount = 12
	dust.lifetime = 0.45
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(9, 3)
	dust.direction = Vector2.UP
	dust.spread = 55.0
	dust.gravity = Vector2(0, -30)
	dust.initial_velocity_min = 15.0
	dust.initial_velocity_max = 40.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 4.0
	dust.color = Color(0.65, 0.8, 0.95, 0.35)
	dust.position = Vector2(0, 26)
	dust.emitting = false
	add_child(dust)

	trail = CPUParticles2D.new()
	trail.amount = 26
	trail.lifetime = 0.28
	trail.local_coords = false
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 30.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 5.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.35, 0.95, 1.0, 0.85), Color(0.35, 0.95, 1.0, 0.0)])
	trail.color_ramp = g
	trail.emitting = false
	add_child(trail)

	burst = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 14
	burst.lifetime = 0.35
	burst.local_coords = false
	burst.direction = Vector2.UP
	burst.spread = 80.0
	burst.gravity = Vector2(0, 900)
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 230.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(0.65, 0.85, 1.0, 0.7)
	burst.position = Vector2(0, 24)
	burst.emitting = false
	add_child(burst)


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.name = "Cam"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.zoom = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()
	add_to_group("camera")


func setup_camera(bounds: Rect2) -> void:
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.reset_smoothing()


func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


# --- Main loop ------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _is_dead:
		# Keep the camera shake alive while dead and tick the spawn shield.
		if _spawn_shield > 0.0:
			_spawn_shield -= delta
		_update_shake(delta)
		return

	_spawn_shield = maxf(0.0, _spawn_shield - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)

	var axis := 0.0
	if active and control_enabled:
		axis = Input.get_axis("move_left", "move_right")

	if axis != 0.0:
		_facing = signf(axis)

	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	if active and control_enabled and Input.is_action_just_pressed("dash") \
			and _can_dash and _dash_cooldown <= 0.0 and _dash_timer <= 0.0:
		_start_dash(axis)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		# Only solid hits straight ahead end a dash; sliding along the
		# floor must NOT cancel it (was killing ground dashes instantly).
		if is_on_wall() or is_on_ceiling():
			_end_dash()
	else:
		_apply_gravity(delta)
		_horizontal_move(delta, axis)
		_wall_interactions(delta, axis)
		_jumping(delta, axis)
		move_and_slide()

	_post_move(delta)
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.8)
		var s := _trauma * _trauma
		cam.offset = Vector2(
			randf_range(-1.0, 1.0) * 14.0 * s,
			randf_range(-1.0, 1.0) * 10.0 * s)
	else:
		cam.offset = Vector2.ZERO


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)


func _horizontal_move(delta: float, axis: float) -> void:
	if _wall_lock > 0.0:
		# Wall-jump kick in progress: input can't override it yet.
		velocity.x = move_toward(velocity.x, 0.0, AIR_FRICTION * 0.5 * delta)
		return
	var on_floor := is_on_floor()
	if absf(axis) > 0.01:
		var a := ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, axis * SPEED, a * delta)
	else:
		var f := FRICTION if on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, f * delta)


func _wall_interactions(_delta: float, axis: float) -> void:
	if not is_on_floor() and is_on_wall_only():
		var normal := get_wall_normal()
		var pressing_into_wall := (normal.x > 0.0 and Input.is_action_pressed("move_left")) \
			or (normal.x < 0.0 and Input.is_action_pressed("move_right"))
		if pressing_into_wall or (absf(axis) > 0.01 and signf(axis) == -signf(normal.x)):
			if velocity.y > 0.0:
				velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
			_jumps_used = mini(_jumps_used, 1)
			_can_dash = true


func _jumping(delta: float, _axis: float) -> void:
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)
	if active and control_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

	if _jump_buffer > 0.0:
		if is_on_wall_only():
			_do_wall_jump()
		elif _coyote > 0.0:
			_do_ground_jump()
		elif _jumps_used < _max_jumps:
			_do_air_jump()

	# Variable jump height.
	if active and control_enabled and Input.is_action_just_released("jump") \
			and velocity.y < 0.0 and not _cut_jump:
		velocity.y *= JUMP_CUT
		_cut_jump = true


func _do_ground_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_coyote = 0.0
	_jump_buffer = 0.0
	_cut_jump = false
	_sfx("jump")
	_burst_fx()
	_squash(Vector2(0.72, 1.28))


func _do_air_jump() -> void:
	velocity.y = JUMP_VELOCITY * 0.92
	velocity.x = move_toward(velocity.x, _facing * SPEED, 200.0)
	_jumps_used += 1
	_jump_buffer = 0.0
	_cut_jump = false
	_sfx("double_jump", -4.0)
	_burst_fx()
	_spin_fx()
	_squash(Vector2(0.78, 1.22))
	_spawn_double_jump_slash()


func _do_wall_jump() -> void:
	var normal := get_wall_normal()
	velocity.x = normal.x * WALL_JUMP_X
	velocity.y = WALL_JUMP_Y
	_facing = signf(normal.x)
	_wall_lock = 0.16
	_jumps_used = mini(_jumps_used, 1)
	_can_dash = true
	_jump_buffer = 0.0
	_cut_jump = false
	_sfx("wall_jump", -3.0)
	_burst_fx()
	shake(0.14)
	_squash(Vector2(0.75, 1.25))
	_spawn_wall_jump_slash(normal.x)


func _start_dash(axis: float) -> void:
	var dir_x := axis
	if absf(dir_x) < 0.01:
		dir_x = _facing
	_dash_dir = Vector2(signf(dir_x), 0.0)
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN + _dash_cooldown_offset
	_can_dash = false
	_cut_jump = true
	velocity = _dash_dir * DASH_SPEED
	trail.emitting = true
	_sfx("dash")
	shake(0.18)
	_cam_punch(0.08)
	_squash(Vector2(1.25, 0.78))
	_spawn_dash_slash()


func _end_dash() -> void:
	_dash_timer = 0.0
	trail.emitting = false


func _post_move(delta: float) -> void:
	# Landing detection.
	if is_on_floor() and not _was_on_floor:
		_jumps_used = 0
		_can_dash = true
		_cut_jump = false
		if not _is_dead and _fall_peak > 260.0:
			_sfx("land", -9.0)
			_squash(Vector2(1.28, 0.74))
			if _fall_peak > 700.0:
				shake(0.2)
		_fall_peak = 0.0
	elif not is_on_floor():
		_fall_peak = maxf(_fall_peak, velocity.y)
	_was_on_floor = is_on_floor()

	# Visual updates.
	vis.scale.x = _facing if not _is_dead else vis.scale.x
	var tilt := clampf(velocity.x * 0.00025, -0.09, 0.09)
	if is_on_floor():
		tilt *= 0.4
	squash_node.rotation = lerp_angle(squash_node.rotation, tilt, 10.0 * delta)
	var look_x := clampf(velocity.x / SPEED, -1.0, 1.0) * 1.8
	var look_y := clampf(velocity.y / 900.0, -1.0, 1.0) * 1.6
	pupil_l.position = Vector2(look_x, look_y)
	pupil_r.position = Vector2(look_x, look_y)
	antenna.rotation = clampf(-velocity.x * 0.0009, -0.45, 0.45)

	dust.emitting = is_on_floor() and absf(velocity.x) > 60.0 and active and not _is_dead

	_animate_character(delta)


# --- Character animation --------------------------------------------------
func _animate_character(delta: float) -> void:
	_anim_time += delta
	_animate_legs(delta)
	_animate_scarf(delta)
	_animate_idle(delta)
	_animate_face(delta)


func _animate_legs(delta: float) -> void:
	var stride := clampf(absf(velocity.x) / SPEED, 0.0, 1.0)
	var target_l: Vector2
	var target_r: Vector2
	if is_on_floor():
		_run_phase += absf(velocity.x) * delta * 0.055
		if stride > 0.04:
			target_l = Vector2(HIP_L.x + sin(_run_phase) * 11.0 * stride,
					FOOT_Y - maxf(0.0, sin(_run_phase)) * 7.5 * stride)
			target_r = Vector2(HIP_R.x + sin(_run_phase + PI) * 11.0 * stride,
					FOOT_Y - maxf(0.0, sin(_run_phase + PI)) * 7.5 * stride)
		else:
			target_l = Vector2(-5.0, FOOT_Y)
			target_r = Vector2(5.0, FOOT_Y)
	else:
		_run_phase = 0.0
		# Airborne pose blends tucked (rising) into reaching (falling).
		var k := clampf((velocity.y + 320.0) / 640.0, 0.0, 1.0)
		target_l = Vector2(-4.0, 17.0).lerp(Vector2(-8.0, 23.0), k)
		target_r = Vector2(6.0, 19.0).lerp(Vector2(7.0, 22.0), k)
	var rate := 20.0 if is_on_floor() else 11.0
	_foot_l = _foot_l.lerp(target_l, minf(1.0, rate * delta))
	_foot_r = _foot_r.lerp(target_r, minf(1.0, rate * delta))
	leg_l.points = PackedVector2Array([HIP_L, _foot_l])
	leg_r.points = PackedVector2Array([HIP_R, _foot_r])


func _animate_scarf(delta: float) -> void:
	_scarf_pts[0] = Vector2(0, -18)
	for i in range(1, SCARF_SEGS):
		var p := _scarf_pts[i]
		p += Vector2(-velocity.x * 0.013, -velocity.y * 0.006 + 34.0) \
				* delta * float(i)
		p.y += sin(_anim_time * 10.0 - float(i) * 0.95) * 0.38
		var d := p - _scarf_pts[i - 1]
		if d.length() < 0.01:
			d = Vector2(SCARF_SEG_LEN, 0)
		_scarf_pts[i] = _scarf_pts[i - 1] + d.normalized() * SCARF_SEG_LEN
	scarf.points = _scarf_pts


func _animate_idle(delta: float) -> void:
	var bob_target := 0.0
	if is_on_floor() and absf(velocity.x) < 12.0:
		bob_target = sin(_anim_time * 2.6) * 1.4
	_bob_y = lerpf(_bob_y, bob_target, minf(1.0, 8.0 * delta))
	squash_node.position.y = _bob_y

	var pulse := 1.0 + sin(_anim_time * 4.2) * 0.12
	core_dot.scale = Vector2(pulse, pulse)
	core_glow.scale = Vector2(pulse * 1.15, pulse * 1.15)
	var bulb_pulse := 1.0 + sin(_anim_time * 6.0) * 0.16
	bulb.scale = Vector2(bulb_pulse, bulb_pulse)
	bulb_glow.scale = Vector2(bulb_pulse * 1.2, bulb_pulse * 1.2)


func _animate_face(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.4, 5.2)
		var tw := create_tween()
		tw.tween_property(eye_l, "scale:y", 0.08, 0.06)
		tw.parallel().tween_property(eye_r, "scale:y", 0.08, 0.06)
		tw.tween_interval(0.05)
		tw.tween_property(eye_l, "scale:y", 1.0, 0.07)
		tw.parallel().tween_property(eye_r, "scale:y", 1.0, 0.07)


# --- Helpers --------------------------------------------------------------
func dash_ratio() -> float:
	if _dash_timer > 0.0:
		return 1.0
	return clampf(1.0 - _dash_cooldown / DASH_COOLDOWN, 0.0, 1.0)


## Adjust this session's dash cooldown (Living World adaptation). Positive
## slows dashes, negative makes them faster. Clamped to stay playable.
func set_dash_cooldown_offset(delta: float) -> void:
	_dash_cooldown_offset = clampf(delta, -0.2, 0.2)
	print("[Player] dash cooldown offset set to ", _dash_cooldown_offset)


func refresh_air_moves() -> void:
	## Called by springs etc.
	_jumps_used = 0
	_can_dash = true
	_cut_jump = false


func bounce(strength: float) -> void:
	velocity.y = -strength
	_cut_jump = false
	refresh_air_moves()
	_squash(Vector2(0.7, 1.32))


func die() -> void:
	if _is_dead or not active or _spawn_shield > 0.0:
		return
	_is_dead = true
	control_enabled = false
	_end_dash()
	dust.emitting = false
	trail.emitting = false
	velocity = Vector2.ZERO
	_sfx("death")
	shake(0.55)
	_cam_punch(0.14)
	_collision_shape.set_deferred("disabled", true)
	_spawn_death_particles()
	_spawn_death_slash()
	vis.visible = false
	scarf.visible = false
	died.emit()


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_is_dead = false
	control_enabled = true
	active = true
	_jumps_used = 0
	_can_dash = true
	_coyote = 0.0
	_jump_buffer = 0.0
	_cut_jump = false
	_dash_timer = 0.0
	_was_on_floor = false
	_spawn_shield = 0.45   # brief immunity; also eats any stale hazard events
	vis.visible = true
	scarf.visible = true
	vis.scale.x = 1.0
	squash_node.rotation = 0.0
	squash_node.scale = Vector2.ONE
	_run_phase = 0.0
	_foot_l = Vector2(-5.0, FOOT_Y)
	_foot_r = Vector2(5.0, FOOT_Y)
	for i in SCARF_SEGS:
		_scarf_pts[i] = Vector2(0, -18 + i * SCARF_SEG_LEN)
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_collision_shape.set_deferred("disabled", false)
	if cam != null:
		cam.reset_smoothing()
	_cam_punch(0.1)
	_spawn_respawn_ring()


## Quick camera zoom punch for impacts (dash, death, respawn...).
func _cam_punch(z: float) -> void:
	if cam == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	cam.zoom = Vector2(1.0 + z, 1.0 + z)
	_cam_tween = create_tween()
	_cam_tween.tween_property(cam, "zoom", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Expanding neon ring shown where the player re-materialises.
func _spawn_respawn_ring() -> void:
	var ring := RespawnRing.new()
	get_parent().add_child(ring)
	ring.global_position = global_position


func _spawn_death_particles() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 34
	p.lifetime = 0.6
	p.local_coords = false
	p.spread = 180.0
	p.gravity = Vector2(0, 1300)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 420.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#f472b6"), Color(0.95, 0.45, 0.71, 0.0)])
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _squash(s: Vector2) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	squash_node.scale = s
	_squash_tween = create_tween()
	_squash_tween.tween_property(squash_node, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _burst_fx() -> void:
	burst.restart()
	burst.emitting = true


func _spin_fx() -> void:
	var tw := create_tween()
	tw.tween_property(squash_node, "rotation", squash_node.rotation + TAU, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sfx(n: String, vol_db: float = 0.0) -> void:
	Globals.play_sfx(n, vol_db)


func _spawn_dash_slash() -> void:
	var tint := Color(1.0, 0.6, 0.2, 0.85)  # warm orange tint
	SlashEffect.spawn(get_parent(), global_position,
			SlashEffect.SlashType.FIRE, 0.08, tint, 1.4,
			_dash_dir.x < 0.0)


func _spawn_wall_jump_slash(dir_x: float) -> void:
	var tint := Color(0.6, 0.8, 1.0, 0.8)  # cool blue tint
	SlashEffect.spawn(get_parent(), global_position + Vector2(dir_x * 12, -5),
			SlashEffect.SlashType.LIGHTNING, 0.06, tint, 1.6,
			dir_x < 0.0)


func _spawn_death_slash() -> void:
	var tint := Color(0.9, 0.3, 0.5, 0.9)  # rose/red tint
	SlashEffect.spawn(get_parent(), global_position,
			SlashEffect.SlashType.POISON, 0.1, tint, 0.8)


func _spawn_double_jump_slash() -> void:
	var tint := Color(0.6, 1.0, 0.8, 0.7)  # wind/green tint
	SlashEffect.spawn(get_parent(), global_position + Vector2(0, 10),
			SlashEffect.SlashType.DOUBLE_WIND, 0.05, tint, 1.2)


## Self-freeing expanding ring drawn procedurally (no assets).
class RespawnRing:
	extends Node2D

	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= 0.5:
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / 0.45, 0.0, 1.0)
		var r := 10.0 + k * 58.0
		var c := Color(0.45, 0.95, 1.0, 0.85 * (1.0 - k))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 3.0)
		draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 32,
				Color(0.95, 0.45, 0.71, 0.5 * (1.0 - k)), 2.0)
