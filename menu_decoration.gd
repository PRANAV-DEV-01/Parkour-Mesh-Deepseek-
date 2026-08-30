class_name MenuDecoration
extends Node2D
## Adds decorative slash effect icons and animated particles to menus.

const ICON_PATHS := {
	"fire": "res://assets/ui_icons/Icons_Fire Slash.png",
	"lightning": "res://assets/ui_icons/Icons_Lightning Slash.png",
	"water": "res://assets/ui_icons/Icons_Water Slash.png",
	"wind": "res://assets/ui_icons/Icons_Wind Slash.png",
	"poison": "res://assets/ui_icons/Icons_Poisonous Slash.png",
	"ultimate": "res://assets/ui_icons/Icons_Ultimate Slash.png",
}

static func add_icon(parent: Node2D, pos: Vector2, icon_name: String,
		size := 64.0, alpha := 0.35) -> Sprite2D:
	var path: String = ICON_PATHS.get(icon_name, "")
	if path.is_empty():
		return null
	var tex := AssetLoader.load_texture_scaled(path, size)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.position = pos
	sprite.modulate = Color(1, 1, 1, alpha)
	sprite.z_index = -5
	parent.add_child(sprite)

	var tw := sprite.create_tween().set_loops()
	tw.tween_property(sprite, "rotation", TAU, 6.0)
	tw.parallel().tween_property(sprite, "modulate:a", alpha * 0.6, 1.5)
	tw.tween_property(sprite, "modulate:a", alpha, 1.5)
	return sprite


static func add_floating_particles(parent: Node2D, bounds: Rect2,
		count := 20, color := Color(0.35, 0.85, 1.0)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = 4.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = bounds.size / 2.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.color = color
	p.emitting = true
	parent.add_child(p)
	return p
