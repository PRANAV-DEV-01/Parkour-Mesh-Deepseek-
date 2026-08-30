extends Node
## Timeline probe around spike death + respawn.

func _ready() -> void:
	var lvl: Node2D = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	add_child(lvl)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = lvl.get_node("Player")
	var last_dead := false
	var last_pos := Vector2.ZERO
	player.global_position = Vector2(2170, -40)
	var t := 0.0
	while t < 4.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if player._is_dead != last_dead or player.global_position.distance_to(last_pos) > 8.0:
			print("t=%.2f dead=%s pos=%s layer=%d active=%s respawning=%s ckpt=%s" % [
				t, player._is_dead, player.global_position.round(),
				player.collision_layer, player.active, lvl._respawning, lvl.checkpoint_pos])
			last_dead = player._is_dead
			last_pos = player.global_position
	get_tree().quit()
