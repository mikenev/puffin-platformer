extends CanvasLayer
## In-level HUD: lives, fish, score, world-level. Driven entirely by GameState signals.

var _lives: PixelLabel
var _fish: PixelLabel
var _score: PixelLabel
var _world: PixelLabel

func _ready() -> void:
	layer = 10
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.07, 0.16, 0.55)
	bar.size = Vector2(256, 10)
	add_child(bar)
	_lives = _label(Vector2(14, 2))
	_fish = _label(Vector2(66, 2))
	_score = _label(Vector2(118, 2))
	_world = _label(Vector2(204, 2))
	var icons := _Icons.new()
	add_child(icons)
	GameState.lives_changed.connect(func(v: int) -> void: _lives.text = "*%02d" % v)
	GameState.fish_changed.connect(func(v: int) -> void: _fish.text = "*%02d" % v)
	GameState.score_changed.connect(func(v: int) -> void: _score.text = "%07d" % v)
	GameState.level_changed.connect(func(w: int, l: int) -> void: _world.text = "W %d-%d" % [w, l])
	_lives.text = "*%02d" % GameState.lives
	_fish.text = "*%02d" % GameState.fish
	_score.text = "%07d" % GameState.score
	_world.text = "W " + GameState.world_level_text()

func _label(p: Vector2) -> PixelLabel:
	var l := PixelLabel.new()
	l.position = p
	add_child(l)
	return l

class _Icons extends Node2D:
	func _draw() -> void:
		# Puffin head (lives)
		draw_rect(Rect2(4, 2, 6, 6), Color8(24, 24, 32))
		draw_rect(Rect2(6, 4, 3, 3), Color8(240, 240, 232))
		draw_rect(Rect2(2, 4, 3, 2), Color8(240, 120, 32))
		# Fish
		draw_rect(Rect2(56, 4, 6, 3), Color8(150, 200, 230))
		draw_rect(Rect2(55, 5, 1, 1), Color8(150, 200, 230))
		draw_rect(Rect2(62, 3, 2, 5), Color8(110, 160, 200))
		draw_rect(Rect2(57, 4, 1, 1), Color8(20, 20, 30))
