extends Control
## Title screen + main menu. Plays title_theme through AudioManager.
## States: TITLE ("PRESS START") -> MENU (Start/Options/Quit) <-> OPTIONS.

const LEVEL_SCENE := "res://scenes/world/world_level.tscn"
const SKY_TOP := Color8(40, 56, 128)
const SKY_BOTTOM := Color8(112, 168, 232)
const SEA := Color8(32, 80, 152)
const CLIFF := Color8(72, 64, 72)

var _t := 0.0
var _press: PixelLabel
var _menu: MenuList
var _options: OptionsMenu
var _state := "title"

func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioBridge.play_music("title_theme")
	var title := PixelLabel.new()
	title.text = "PUFFIN"
	title.pixel_scale = 4
	title.color = Color8(255, 240, 200)
	title.position = Vector2((256 - PixelFont.text_width("PUFFIN", 4)) / 2, 36)
	add_child(title)
	var sub := PixelLabel.new()
	sub.text = "PLATFORMER"
	sub.pixel_scale = 2
	sub.color = Color8(255, 200, 64)
	sub.position = Vector2((256 - PixelFont.text_width("PLATFORMER", 2)) / 2, 62)
	add_child(sub)
	_press = PixelLabel.new()
	_press.text = "PRESS START"
	_press.position = Vector2((256 - PixelFont.text_width("PRESS START")) / 2, 150)
	add_child(_press)
	_menu = MenuList.new()
	_menu.position = Vector2(100, 138)
	var items: Array[Dictionary] = [{"id": "start", "label": "START"}, {"id": "options", "label": "OPTIONS"}]
	if not OS.has_feature("web"):
		items.append({"id": "quit", "label": "QUIT"})
	_menu.set_items(items)
	_menu.item_selected.connect(_on_menu)
	add_child(_menu)
	_options = OptionsMenu.new()
	_options.position = Vector2(64, 132)
	_options.closed.connect(_show_menu)
	add_child(_options)
	_options.hide()
	_set_state("title")

func _set_state(s: String) -> void:
	_state = s
	_press.visible = s == "title"
	_menu.visible = s == "menu"
	_menu.active = s == "menu"
	_options.visible = s == "options"

func _show_menu() -> void:
	_set_state("menu")

func _unhandled_input(event: InputEvent) -> void:
	if _state == "title" and (event.is_action_pressed("ui_accept") or event.is_action_pressed("pause") or event.is_action_pressed("jump")):
		get_viewport().set_input_as_handled()
		AudioBridge.play_sfx("powerup")
		_set_state("menu")

func _on_menu(id: String) -> void:
	match id:
		"start":
			GameState.new_game()
			get_tree().change_scene_to_file(LEVEL_SCENE)
		"options":
			_set_state("options")
		"quit":
			get_tree().quit()

func _process(delta: float) -> void:
	_t += delta
	_press.color.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.0
	queue_redraw()

func _draw() -> void:
	# Banded sky (SNES-style dithered gradient done with hard bands).
	for i in 14:
		draw_rect(Rect2(0, i * 10, 256, 10), SKY_TOP.lerp(SKY_BOTTOM, i / 13.0))
	# Sea with scrolling wave highlights.
	draw_rect(Rect2(0, 140, 256, 84), SEA)
	for row in 6:
		var y := 146 + row * 12
		var off := int(_t * (8 + row * 4)) % 32
		for x in range(-32, 288, 32):
			draw_rect(Rect2(x + off + (row % 2) * 16, y, 8, 1), Color8(96, 160, 224))
	# Cliff with a little puffin silhouette on top.
	draw_rect(Rect2(196, 104, 60, 120), CLIFF)
	draw_rect(Rect2(204, 96, 52, 8), CLIFF)
	draw_rect(Rect2(204, 94, 52, 2), Color8(96, 152, 72))
	var bob := int(_t * 2) % 2
	draw_rect(Rect2(222, 82 - bob, 8, 12), Color8(24, 24, 32))        # body
	draw_rect(Rect2(224, 86 - bob, 5, 7), Color8(240, 240, 232))      # belly
	draw_rect(Rect2(219, 84 - bob, 4, 3), Color8(240, 120, 32))       # beak
	draw_rect(Rect2(219, 85 - bob, 4, 1), Color8(232, 200, 48))
	draw_rect(Rect2(223, 83 - bob, 1, 1), Color8(255, 255, 255))      # eye
	draw_rect(Rect2(223, 94 - bob, 2, 1 + bob), Color8(240, 120, 32)) # feet
	draw_rect(Rect2(227, 94 - bob, 2, 1 + bob), Color8(240, 120, 32))
	PixelFont.draw_text(self, "ORIGINAL GAME - 2026", Vector2(4, 216), Color8(160, 190, 230))
