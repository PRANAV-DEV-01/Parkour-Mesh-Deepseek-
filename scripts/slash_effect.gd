class_name SlashEffect
extends Node2D
## Animated slash VFX loaded from PNG sprite frames at runtime.
## Spawns as a self-freeing one-shot animation. Used for dashes,
## wall jumps, coin collection, death and goal effects.

enum SlashType { FIRE, LIGHTNING, WATER, WIND, POISON, DOUBLE_WIND, ULTIMATE }

var slash_type := SlashType.FIRE
var tint := Color.WHITE
var speed_scale := 1.0

var _sprite: AnimatedSprite2D

const _FOLDER_MAP := {
	SlashType.FIRE: "res://assets/slash_effects/fire/",
	SlashType.LIGHTNING: "res://assets/slash_effects/lightning/",
	SlashType.WATER: "res://assets/slash_effects/water/",
	SlashType.WIND: "res://assets/slash_effects/wind/",
	SlashType.POISON: "res://assets/slash_effects/poison/",
	SlashType.DOUBLE_WIND: "res://assets/slash_effects/double_wind/",
	SlashType.ULTIMATE: "res://assets/slash_effects/ultimate/",
}

const _FRAME_COUNTS := {
	SlashType.FIRE: 12,
	SlashType.LIGHTNING: 12,
	SlashType.WATER: 12,
	SlashType.WIND: 18,
	SlashType.POISON: 24,
	SlashType.DOUBLE_WIND: 18,
	SlashType.ULTIMATE: 20,
}

const _FRAME_NAMES := {
	SlashType.FIRE: "Fire Slash",
	SlashType.LIGHTNING: "Lightning Slash",
	SlashType.WATER: "Water Slash",
	SlashType.WIND: "Double Wind Slashes",
	SlashType.POISON: "Poisonous Slashes",
	SlashType.DOUBLE_WIND: "Double Wind Slashes",
	SlashType.ULTIMATE: "Ultimate Slash",
}

static var _cache: Dictionary = {}


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames(slash_type)
	_sprite.speed_scale = speed_scale
	_sprite.modulate = tint
	_sprite.play(&"default")
	_sprite.animation_finished.connect(queue_free)
	add_child(_sprite)


static func _get_frames(type: SlashType) -> SpriteFrames:
	if _cache.has(type):
		return _cache[type]

	var sf := SpriteFrames.new()
	sf.add_animation(&"default")
	sf.set_animation_speed(&"default", 24.0)
	sf.set_animation_loop(&"default", false)

	# First try the real sprite-sheet folder (present when the full asset
	# pack was migrated in). Load whatever frames match the expected name.
	var folder: String = _FOLDER_MAP[type]
	var frame_count: int = _FRAME_COUNTS[type]
	var frame_name: String = _FRAME_NAMES[type]
	var loaded := 0
	for i in range(1, frame_count + 1):
		var img: Image = Image.load_from_file("%s%s_Frame_%02d.png" % [folder, frame_name, i])
		if img == null:
			break
		sf.add_frame(&"default", ImageTexture.create_from_image(img))
		loaded += 1

	# Fallback: the source folder is missing (restructure left only loose
	# frames at the repo root). Sample whatever loose "X_Frame_0N.png" files
	# exist so dashes / wall-jumps still read as animated slashes.
	if loaded == 0:
		loaded = _fallback_frames(type, sf)

	_cache[type] = sf
	return sf


static func _fallback_frames(type: SlashType, sf: SpriteFrames) -> int:
	var frame_names := {
		SlashType.FIRE: "Icons_Fire Slash",
		SlashType.LIGHTNING: "Icons_Lightning Slash",
		SlashType.WATER: "Icons_Water Slash",
		SlashType.WIND: "Double Wind Slashes",
		SlashType.POISON: "Icons_Poisonous Slash",
		SlashType.DOUBLE_WIND: "Double Wind Slashes",
		SlashType.ULTIMATE: "Icons_Ultimate Slash",
	}
	var base_name: String = frame_names[type]
	var added := 0
	for i in range(1, 20):
		var path := "res://%s_Frame_%02d.png" % [base_name, i]
		var img: Image = Image.load_from_file(path)
		if img == null:
			img = Image.load_from_file("res://%s.png" % base_name)
		if img == null:
			break
		var tex := ImageTexture.create_from_image(img)
		sf.add_frame(&"default", tex)
		added += 1
		if sf.get_frame_count(&"default") > 1:
			break
	return added


## Convenience factory: creates, parents, and returns a configured SlashEffect.
static func spawn(parent: Node2D, pos: Vector2, type: SlashType,
		scale_val := 1.0, p_tint := Color.WHITE, spd := 1.0,
		flip_x := false) -> SlashEffect:
	if parent == null:
		return null
	var fx := SlashEffect.new()
	fx.slash_type = type
	fx.tint = p_tint
	fx.speed_scale = spd
	parent.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector2(scale_val, scale_val) * (Vector2(-1, 1) if flip_x else Vector2.ONE)
	return fx
