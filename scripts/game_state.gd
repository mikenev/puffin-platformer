extends Node
## Global run state (autoload "GameState"). UI listens to the signals; gameplay calls the methods.

signal lives_changed(lives: int)
signal fish_changed(fish: int)
signal score_changed(score: int)
signal level_changed(world: int, level: int)
signal game_over
signal settings_changed

const START_LIVES := 3
const MAX_LIVES := 99
const FISH_PER_LIFE := 100
const FISH_SCORE := 10
const SETTINGS_PATH := "user://settings.cfg"

var lives := START_LIVES
var fish := 0
var score := 0
var world := 1
var level := 1
var music_volume := 0.8
var sfx_volume := 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func new_game() -> void:
	lives = START_LIVES
	fish = 0
	score = 0
	set_level(1, 1)
	_emit_all()

func set_level(w: int, l: int) -> void:
	world = w
	level = l
	level_changed.emit(world, level)

func add_fish(n := 1) -> void:
	fish += n
	add_score(FISH_SCORE * n)
	while fish >= FISH_PER_LIFE:
		fish -= FISH_PER_LIFE
		add_life()
	fish_changed.emit(fish)

func add_score(n: int) -> void:
	score = mini(score + n, 9999999)
	score_changed.emit(score)

func add_life(n := 1) -> void:
	lives = mini(lives + n, MAX_LIVES)
	lives_changed.emit(lives)

## Returns true if the player still has lives left.
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives == 0:
		game_over.emit()
		return false
	return true

func world_level_text() -> String:
	return "%d-%d" % [world, level]

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	AudioBridge.set_volume("Music", music_volume)
	settings_changed.emit()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	AudioBridge.set_volume("SFX", sfx_volume)
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	# Defer so AudioManager (registered after us or before) has built its players/buses.
	call_deferred("_apply_volumes")

func _apply_volumes() -> void:
	AudioBridge.set_volume("Music", music_volume)
	AudioBridge.set_volume("SFX", sfx_volume)

func _emit_all() -> void:
	lives_changed.emit(lives)
	fish_changed.emit(fish)
	score_changed.emit(score)
	level_changed.emit(world, level)
