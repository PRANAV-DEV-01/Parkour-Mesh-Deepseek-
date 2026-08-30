class_name Spike
extends Area2D
## Row of deadly spikes. Rotate the node to point them in any direction.

@export var count := 4
@export var spacing := 30.0
@export var height := 26.0

var _base_glow: Line2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("accent")
	var w_total := count * spacing

	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(Vector2(-w_total / 2.0, 0))
	cols.append(Color("#7f1d3a"))
	for i in count:
		var x0 := -w_total / 2.0 + i * spacing
		pts.append(Vector2(x0 + spacing * 0.5, -height))
		cols.append(Color("#fb7185"))
		pts.append(Vector2(x0 + spacing, 0))
		cols.append(Color("#7f1d3a"))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.vertex_colors = cols
	add_child(poly)

	var base := Polygon2D.new()
	base.color = Color("#4c0519")
	base.polygon = PackedVector2Array([
		Vector2(-w_total / 2.0, 0), Vector2(w_total / 2.0, 0),
		Vector2(w_total / 2.0, 5.0), Vector2(-w_total / 2.0, 5.0),
	])
	add_child(base)

	_base_glow = Line2D.new()
	_base_glow.width = 5.0
	_base_glow.default_color = Color("#f43f5e", 0.25)
	add_child(_base_glow)
	_base_glow.points = PackedVector2Array([
		Vector2(-w_total / 2.0 + 2.0, 2.5), Vector2(w_total / 2.0 - 2.0, 2.5),
	])

	# Kill zone slightly smaller than the visual tips (fair hitbox).
	# One convex triangle per tooth - no concave polygons needed.
	for i in count:
		var x0 := -w_total / 2.0 + i * spacing
		var tri := ConvexPolygonShape2D.new()
		tri.points = PackedVector2Array([
			Vector2(x0 + 2.0, -1.0),
			Vector2(x0 + spacing * 0.5, -height * 0.72),
			Vector2(x0 + spacing - 2.0, -1.0),
		])
		var cs := CollisionShape2D.new()
		cs.shape = tri
		add_child(cs)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# die() guards against dead/shielded players, but skip corpses
		# entirely so stale overlap events can never re-kill anyone.
		if not body._is_dead and body._spawn_shield <= 0.0:
			body.die()

func set_accent(_c: Color) -> void:
	pass
