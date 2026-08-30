class_name PlatformTextureOverlay
extends Node2D
## Adds a subtle tiled texture overlay on top of a platform body.
## The texture is loaded at runtime and displayed as a low-alpha Sprite2D.

const _TEXTURE_MAP := {
	"neutral": "res://platformer_texture.png",
	"blue": "res://platformer_texture_blue.png",
	"red": "res://platformer_texture_red.png",
	"green": "res://platformer_texture_green.png",
	"yellow": "res://platformer_texture_yellow.png",
}

static func add_to(parent: Node2D, p_size: Vector2,
		theme := "neutral", alpha := 0.12) -> void:
	var path: String = _TEXTURE_MAP.get(theme, _TEXTURE_MAP["neutral"])
	var tex := AssetLoader.load_texture_scaled(path, minf(p_size.x, p_size.y) * 0.9)
	if tex == null:
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.scale = Vector2(
		p_size.x / tex.get_width() * 1.1,
		p_size.y / tex.get_height() * 1.1)
	sprite.modulate = Color(1, 1, 1, alpha)
	sprite.z_index = -1
	parent.add_child(sprite)
