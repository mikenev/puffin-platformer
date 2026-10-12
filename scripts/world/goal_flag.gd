class_name GoalFlag
extends Area2D
## End-of-course flag pole. Position = base of the pole (top of the ground tile). Emits `reached`.

signal reached

const HEIGHT := 64
var _t := 0.0
var _done := false

func _ready() -> void:
	add_to_group("goal")
	monitorable = false
	collision_layer = 0
	collision_mask = Enemy.LAYER_PLAYER  # the puffin is on the player layer only
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, HEIGHT)
	cs.shape = shape
	cs.position = Vector2(0, -HEIGHT / 2.0)
	add_child(cs)
	body_entered.connect(func(b: Node) -> void:
		if not _done and b is Puffin and not (b as Puffin).is_dying():
			_done = true
			reached.emit())

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-1, -HEIGHT, 2, HEIGHT), Color8(232, 232, 224))
	draw_rect(Rect2(-2, -HEIGHT - 3, 4, 3), Color8(255, 200, 64))
	var wave := int(_t * 6) % 2
	var flag := Color8(232, 80, 56)
	draw_rect(Rect2(1, -HEIGHT + 1, 12, 8), flag)
	draw_rect(Rect2(13, -HEIGHT + 2 + wave, 2, 6), flag)
	draw_rect(Rect2(4, -HEIGHT + 3, 5, 4), Color8(24, 24, 32))     # puffin emblem
	draw_rect(Rect2(6, -HEIGHT + 4, 2, 2), Color8(240, 240, 232))
	draw_rect(Rect2(3, -HEIGHT + 4, 1, 1), Color8(255, 160, 32))
	draw_rect(Rect2(-4, -2, 8, 2), Color8(120, 104, 88))
