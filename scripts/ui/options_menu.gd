class_name OptionsMenu
extends Control
## Music/SFX volume options. Shared by main menu and pause menu. Emits closed on Back/cancel.

signal closed

var _list: MenuList

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var title := PixelLabel.new()
	title.text = "OPTIONS"
	title.position = Vector2(8, 0)
	title.color = Color8(255, 200, 64)
	add_child(title)
	_list = MenuList.new()
	_list.position = Vector2(0, 14)
	add_child(_list)
	_list.item_selected.connect(_on_select)
	_list.value_changed.connect(_on_value)
	visibility_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if _list == null:
		return
	var items: Array[Dictionary] = [
		{"id": "music", "label": "MUSIC", "slider": true, "value": GameState.music_volume},
		{"id": "sfx", "label": "SFX", "slider": true, "value": GameState.sfx_volume},
		{"id": "back", "label": "BACK"},
	]
	_list.set_items(items)
	_list.active = visible

func _on_value(id: String, v: float) -> void:
	if id == "music":
		GameState.set_music_volume(v)
	else:
		GameState.set_sfx_volume(v)

func _on_select(id: String) -> void:
	if id == "back":
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	GameState.save_settings()
	hide()
	closed.emit()
