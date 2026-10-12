extends CanvasLayer
## Pause menu. Toggle with "pause" (Esc/P/Enter, gamepad Start). Runs while the tree is paused.

const TITLE_SCENE := "res://scenes/ui/title.tscn"

var _root: Control
var _menu: MenuList
var _options: OptionsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.size = Vector2(256, 224)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.6)
	dim.size = Vector2(256, 224)
	_root.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color8(24, 32, 80)
	panel.position = Vector2(56, 68)
	panel.size = Vector2(144, 76)
	_root.add_child(panel)
	var border := ReferenceRect.new()
	border.border_color = Color8(255, 200, 64)
	border.editor_only = false
	border.position = panel.position
	border.size = panel.size
	_root.add_child(border)
	var title := PixelLabel.new()
	title.text = "PAUSED"
	title.pixel_scale = 2
	title.color = Color8(255, 240, 200)
	title.position = Vector2(128 - PixelFont.text_width("PAUSED", 2) / 2, 76)
	_root.add_child(title)
	_menu = MenuList.new()
	_menu.position = Vector2(80, 98)
	var items: Array[Dictionary] = [{"id": "resume", "label": "RESUME"}, {"id": "options", "label": "OPTIONS"}, {"id": "title", "label": "QUIT TO TITLE"}]
	_menu.set_items(items)
	_menu.item_selected.connect(_on_menu)
	_root.add_child(_menu)
	_options = OptionsMenu.new()
	_options.position = Vector2(64, 96)
	_options.closed.connect(func() -> void: _menu.show(); _menu.active = true)
	_root.add_child(_options)
	_options.hide()
	_root.hide()

func is_open() -> bool:
	return _root.visible

func toggle() -> void:
	set_open(not _root.visible)

func set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	_options.hide()
	_menu.show()
	_menu.active = open
	_menu.index = 0
	_menu.queue_redraw()
	AudioBridge.play_sfx("stomp")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _options.visible:
			return
		toggle()
	elif is_open() and not _options.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		set_open(false)

func _on_menu(id: String) -> void:
	match id:
		"resume":
			set_open(false)
		"options":
			_menu.hide()
			_menu.active = false
			_options.show()
		"title":
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)
