class_name MenuList
extends Control
## SNES-style vertical menu drawn with PixelFont. Up/down move, accept selects,
## left/right adjust "slider" items (0..10 steps). Emits item_selected(id).

signal item_selected(id: String)
signal value_changed(id: String, value: float)

const STEPS := 10
@export var line_height := 10
@export var text_color := Color8(240, 240, 232)
@export var dim_color := Color8(130, 140, 170)
@export var cursor_color := Color8(255, 200, 64)

## Each item: {id, label, slider(bool), value(0..1)}
var items: Array[Dictionary] = []
var index := 0
var active := true

func set_items(new_items: Array[Dictionary]) -> void:
	items = new_items
	index = 0
	custom_minimum_size = Vector2(120, items.size() * line_height)
	queue_redraw()

func set_value(id: String, v: float) -> void:
	for it in items:
		if it.id == id:
			it.value = v
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or items.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_left"):
		_adjust(-1)
	elif event.is_action_pressed("ui_right"):
		_adjust(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		var it := items[index]
		if not it.get("slider", false):
			AudioBridge.play_sfx("collect_fish")
			get_viewport().set_input_as_handled()
			item_selected.emit(it.id)
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _move(d: int) -> void:
	index = wrapi(index + d, 0, items.size())
	AudioBridge.play_sfx("jump")
	queue_redraw()

func _adjust(d: int) -> void:
	var it := items[index]
	if not it.get("slider", false):
		return
	var steps := clampi(roundi(float(it.value) * STEPS) + d, 0, STEPS)
	it.value = steps / float(STEPS)
	AudioBridge.play_sfx("land")
	value_changed.emit(it.id, it.value)
	queue_redraw()

func _draw() -> void:
	for i in items.size():
		var it := items[i]
		var y := i * line_height
		var sel := i == index
		if sel:
			PixelFont.draw_text(self, ">", Vector2(0, y), cursor_color, 1, Color8(20, 24, 48))
		PixelFont.draw_text(self, str(it.label), Vector2(8, y), text_color if sel else dim_color, 1, Color8(20, 24, 48))
		if it.get("slider", false):
			var bx := 56
			var filled := roundi(float(it.value) * STEPS)
			for s in STEPS:
				var c: Color = cursor_color if s < filled else Color8(50, 58, 96)
				draw_rect(Rect2(bx + s * 5, y, 4, 5), c)
			PixelFont.draw_text(self, str(filled), Vector2(bx + STEPS * 5 + 3, y), text_color if sel else dim_color)
