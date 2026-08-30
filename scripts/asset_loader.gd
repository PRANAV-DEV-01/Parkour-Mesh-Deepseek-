class_name AssetLoader
## Static utility for loading PNG textures at runtime without the Godot import system.
## Caches loaded images to avoid re-loading.

static var _tex_cache: Dictionary = {}

static func load_texture(path: String) -> ImageTexture:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img: Image = Image.load_from_file(path)
	if img == null:
		push_warning("AssetLoader: could not load %s" % path)
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


static func load_texture_scaled(path: String, max_dim: float) -> ImageTexture:
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	var longest := maxf(img.get_width(), img.get_height())
	if longest > max_dim:
		var ratio := max_dim / longest
		img.resize(int(img.get_width() * ratio), int(img.get_height() * ratio),
				Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex
