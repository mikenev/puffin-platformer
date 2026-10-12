class_name FishPickup
extends Area2D
## Collectible fish: +1 fish (and score) via GameState. Original art drawn in code.

const BOB := 1.5
var _t := 0.0
var collected := false

func _ready() -> void:
	add_to_group("fish")
	monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body)
	_t = fmod(position.x * 0.05, TAU)

func _on_body(body: Node) -> void:
	if collected or not body is Puffin or (body as Puffin).is_dying():
		return
	collect()

func collect() -> void:
	collected = true
	if has_node("/root/GameState"):
		get_node("/root/GameState").add_fish(1)
	AudioBridge.play_sfx("collect_fish")
	queue_free()

func _process(delta: float) -> void:
	_t += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var y := roundf(sin(_t) * BOB)
	var body := Color8(150, 200, 232)
	var dark := Color8(72, 120, 176)
	draw_rect(Rect2(-4, -2 + y, 7, 4), body)
	draw_rect(Rect2(-3, -3 + y, 5, 1), body)
	draw_rect(Rect2(-3, 2 + y, 5, 1), dark)
	draw_rect(Rect2(3, -3 + y, 1, 2), dark)   # tail
	draw_rect(Rect2(4, -4 + y, 1, 3), dark)
	draw_rect(Rect2(3, 1 + y, 1, 2), dark)
	draw_rect(Rect2(4, 1 + y, 1, 3), dark)
	draw_rect(Rect2(-3, -1 + y, 1, 1), Color8(16, 24, 40))  # eye
	draw_rect(Rect2(-1, -2 + y, 2, 1), Color8(232, 244, 255)) # shine
