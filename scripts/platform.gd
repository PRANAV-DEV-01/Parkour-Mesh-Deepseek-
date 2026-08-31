class_name Platform
extends StaticBody2D
## Static platform with neon-edged visuals. Size configurable per instance.

@export var size := Vector2(220.0, 40.0)
@export var base_color := Color("#16233f")
@export var edge_color := Color("#22d3ee")

var _edge_line: Line2D
var _glow_line: Line2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("accent")
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)

	var body := Polygon2D.new()
	body.color = base_color
	body.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, size.y / 2.0), Vector2(-size.x / 2.0, size.y / 2.0),
	])
	add_child(body)

	_add_texture_overlay()

	var top := -size.y / 2.0
	_glow_line = Line2D.new()
	_glow_line.width = 7.0
	_glow_line.default_color = Color(edge_color.r, edge_color.g, edge_color.b, 0.22)
	add_child(_glow_line)
	_edge_line = Line2D.new()
	_edge_line.width = 2.5
	_edge_line.default_color = edge_color
	add_child(_edge_line)
	var pts := PackedVector2Array([
		Vector2(-size.x / 2.0 + 1, top), Vector2(size.x / 2.0 - 1, top),
	])
	_glow_line.points = pts
	_edge_line.points = pts


func set_accent(c: Color) -> void:
	edge_color = c
	if _edge_line != null:
		_edge_line.default_color = c
		_glow_line.default_color = Color(c.r, c.g, c.b, 0.22)


## Shared helper so other body types can reuse the same look.
static func add_platform_visuals(parent_node: Node2D, p_size: Vector2,
		base_col := Color("#16233f"), edge_col := Color("#22d3ee")) -> Array[Line2D]:
	var poly := Polygon2D.new()
	poly.color = base_col
	poly.polygon = PackedVector2Array([
		Vector2(-p_size.x / 2.0, -p_size.y / 2.0), Vector2(p_size.x / 2.0, -p_size.y / 2.0),
		Vector2(p_size.x / 2.0, p_size.y / 2.0), Vector2(-p_size.x / 2.0, p_size.y / 2.0),
	])
	parent_node.add_child(poly)

	var glow := Line2D.new()
	glow.width = 7.0
	glow.default_color = Color(edge_col.r, edge_col.g, edge_col.b, 0.22)
	glow.points = PackedVector2Array([
		Vector2(-p_size.x / 2.0 + 1, -p_size.y / 2.0),
		Vector2(p_size.x / 2.0 - 1, -p_size.y / 2.0),
	])
	parent_node.add_child(glow)

	var edge := Line2D.new()
	edge.width = 2.5
	edge.default_color = edge_col
	edge.points = glow.points.duplicate()
	parent_node.add_child(edge)
	return [edge, glow]


func _add_texture_overlay() -> void:
	if size.x < 100.0 or size.y < 20.0:
		return
	var tex := AssetLoader.load_texture_scaled(
			"res://platformer_texture.png",
			minf(size.x, size.y) * 0.85)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.scale = Vector2(
			size.x / tex.get_width() * 1.05,
			size.y / tex.get_height() * 1.05)
	sprite.modulate = Color(1, 1, 1, 0.1)
	sprite.z_index = -1
	add_child(sprite)


## Spawn a plain static Platform instance at a world position, parented under
## the level's "World" node (or the given parent). Used by the Level Adapter
## to add a safety platform without disturbing existing node paths.
static func spawn_visual_static(level: Node2D, world_pos: Vector2,
		p_size: Vector2) -> void:
	var parent: Node = level.get_node_or_null("World")
	if parent == null:
		parent = level
	var plat := Platform.new()
	plat.name = "AdapterPlatform"
	plat.size = p_size
	parent.add_child(plat)
	plat.global_position = world_pos
	print("[Platform] spawned safety platform at ", world_pos)
