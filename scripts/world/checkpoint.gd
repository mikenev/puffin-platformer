class_name Checkpoint
extends Area2D
## Mid-course checkpoint post. Touching it moves the puffin's respawn point here.

var active := false

func _ready() -> void:
	add_to_group("checkpoint")
	monitorable = false
	collision_layer = 0
	collision_mask = Enemy.LAYER_PLAYER  # the puffin is on the player layer only
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 32)
	cs.shape = shape
	cs.position = Vector2(0, -16)
	add_child(cs)
	body_entered.connect(func(b: Node) -> void:
		if not active and b is Puffin and not (b as Puffin).is_dying():
			active = true
			(b as Puffin).spawn_point = global_position + Vector2(0, -8)
			AudioBridge.play_sfx("collect_fish")
			queue_redraw())

func _draw() -> void:
	draw_rect(Rect2(-1, -24, 2, 24), Color8(150, 120, 90))
	var c := Color8(96, 208, 112) if active else Color8(140, 140, 150)
	draw_rect(Rect2(1, -24, 8, 6), c)
	draw_rect(Rect2(-3, -2, 6, 2), Color8(120, 104, 88))
