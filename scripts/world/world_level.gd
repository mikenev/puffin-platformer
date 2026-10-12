class_name WorldLevel
extends Node2D
## Builds a World 1 course from W1Maps (ASCII, see tools/levels/gen_w1.py) into TileMapLayers
## using Art Dev's coastal tileset. Which course is chosen from GameState.world/level
## (or `level_id` when set, e.g. by tests).
##
## Hook points for gameplay code (enemies, power-ups) - this script does NOT spawn them:
##   get_tree().get_nodes_in_group("enemy_spawn")   Marker2D, meta "kind": walker|flyer|crab
##   get_tree().get_nodes_in_group("powerup_spawn") Marker2D, meta "kind": fish_power
## All markers live under the "Spawns" child. `level_built` fires once they exist.

signal level_built
signal level_cleared

const TILE := 16
const LAST_LEVEL := 4
const SCENE_PATH := "res://scenes/world/world_level.tscn"
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const TILESET := "res://art/tiles/coastal_tileset.tres"
const CLEAR_BONUS := 1000
const CLEAR_DELAY := 2.0
const SOLID := "#S"
const ENEMY_KINDS := {"e": "walker", "w": "flyer", "k": "crab"}
const POWERUP_KINDS := {"o": "fish_power"}
## Atlas coords in coastal_tiles.png (see art/tiles/tiles.txt)
const T := {
	"grass_tl": Vector2i(0, 0), "grass_t": Vector2i(1, 0), "grass_tr": Vector2i(2, 0), "grass_single": Vector2i(3, 0),
	"plat_l": Vector2i(4, 0), "plat_m": Vector2i(5, 0), "plat_r": Vector2i(6, 0), "plat_single": Vector2i(7, 0),
	"dirt_l": Vector2i(0, 1), "dirt": Vector2i(1, 1), "dirt_r": Vector2i(2, 1), "dirt_stones": Vector2i(3, 1),
	"grass_col": Vector2i(1, 2), "sand_t": Vector2i(3, 2), "sand": Vector2i(4, 2),
	"water_top": Vector2i(5, 2), "water": Vector2i(6, 2),
	"flower": Vector2i(0, 3), "tuft": Vector2i(1, 3), "rock": Vector2i(2, 3), "shell": Vector2i(3, 3), "post": Vector2i(7, 3),
}

@export var level_id := ""   ## "1-1".."1-4"; empty = use GameState

var map: Array = []
var level_size := Vector2.ZERO
var terrain: TileMapLayer
var decor: TileMapLayer
var spawns: Node2D
var player: Puffin
var _clearing := false
var _game_over := false

func _ready() -> void:
	if level_id == "":
		level_id = "%d-%d" % [_gs("world", 1), _gs("level", 1)]
	if not W1Maps.MAPS.has(level_id):
		push_error("Unknown level %s, falling back to 1-1" % level_id)
		level_id = "1-1"
	map = W1Maps.MAPS[level_id]
	level_size = Vector2(map[0].length() * TILE, map.size() * TILE)
	_add_backdrop()
	_build_tiles()
	_build_objects()
	_setup_camera()
	AudioBridge.play_music("world1_theme")
	level_built.emit()

func _gs(prop: String, fallback: int) -> int:
	var gs := get_node_or_null("/root/GameState")
	return gs.get(prop) if gs else fallback

func cell(x: int, y: int) -> String:
	if y < 0 or y >= map.size() or x < 0 or x >= map[y].length():
		return "."
	return map[y][x]

func _solid(x: int, y: int) -> bool:
	if x < 0 or x >= map[0].length():
		return y < map.size() and _solid(clampi(x, 0, map[0].length() - 1), y)
	return SOLID.contains(cell(x, y))

func _add_backdrop() -> void:
	var bg := _Backdrop.new()
	bg.level_size = level_size
	bg.z_index = -10
	add_child(bg)

func _build_tiles() -> void:
	var ts: TileSet = load(TILESET)
	terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = ts
	decor = TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = ts
	decor.collision_enabled = false
	add_child(terrain)
	add_child(decor)
	for y in map.size():
		for x in map[y].length():
			var c := cell(x, y)
			var coord := Vector2i(-1, -1)
			match c:
				"#":
					coord = _ground_tile(x, y)
				"S":
					coord = T.sand_t if not _solid(x, y - 1) else T.sand
				"=":
					var l := cell(x - 1, y) == "="
					var r := cell(x + 1, y) == "="
					coord = T.plat_m if l and r else (T.plat_r if l else (T.plat_l if r else T.plat_single))
				"~":
					coord = T.water_top
			if coord.x >= 0:
				terrain.set_cell(Vector2i(x, y), 0, coord)
			# Deterministic decoration on open ground tops.
			if SOLID.contains(c) and not _solid(x, y - 1) and cell(x, y - 1) == ".":
				var h: int = (x * 73 + y * 31 + level_id.hash()) % 11
				var d: Array = ["flower", "tuft", "rock"] if c == "#" else ["shell", "rock", "shell"]
				if h < 3:
					decor.set_cell(Vector2i(x, y - 1), 0, T[d[h]])

func _ground_tile(x: int, y: int) -> Vector2i:
	var l := _solid(x - 1, y)
	var r := _solid(x + 1, y)
	if not _solid(x, y - 1):
		if not l and not r:
			return T.grass_single
		return T.grass_tl if not l else (T.grass_tr if not r else T.grass_t)
	if not l:
		return T.dirt_l
	if not r:
		return T.dirt_r
	return T.dirt_stones if (x * 7 + y * 13) % 9 == 0 else T.dirt

func _center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)

func _build_objects() -> void:
	spawns = Node2D.new()
	spawns.name = "Spawns"
	add_child(spawns)
	var pickups := Node2D.new()
	pickups.name = "Pickups"
	add_child(pickups)
	var spawn := _center(2, map.size() - 3)
	var counts := {}
	for y in map.size():
		for x in map[y].length():
			var c := cell(x, y)
			var p := _center(x, y)
			match c:
				"P":
					spawn = p
				"f":
					var fish := FishPickup.new()
					fish.position = p
					pickups.add_child(fish)
				"G":
					var goal := GoalFlag.new()
					goal.name = "Goal"
					goal.position = Vector2(p.x, p.y + TILE / 2.0)
					goal.reached.connect(_on_goal)
					add_child(goal)
				"C":
					var cp := Checkpoint.new()
					cp.position = Vector2(p.x, p.y + TILE / 2.0)
					add_child(cp)
				_:
					var group := ""
					var kind := ""
					if ENEMY_KINDS.has(c):
						group = "enemy_spawn"
						kind = ENEMY_KINDS[c]
					elif POWERUP_KINDS.has(c):
						group = "powerup_spawn"
						kind = POWERUP_KINDS[c]
					if group != "":
						counts[kind] = counts.get(kind, 0) + 1
						var m := Marker2D.new()
						m.name = "%s_%s_%02d" % ["EnemySpawn" if group == "enemy_spawn" else "PowerupSpawn", kind, counts[kind]]
						m.position = p
						m.set_meta("kind", kind)
						m.add_to_group(group)
						spawns.add_child(m)
	player = Puffin.new()
	player.name = "Puffin"
	player.position = spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)

func _setup_camera() -> void:
	var cam := FollowCamera.new()
	cam.name = "Camera"
	cam.target = player
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	cam.make_current()
	player.respawned.connect(cam.snap_to_target)
	cam.snap_to_target()

func _physics_process(_delta: float) -> void:
	if _clearing:
		return
	if Input.is_action_just_pressed("restart"):
		player.respawn(false)
	elif not player.is_dying() and player.global_position.y > level_size.y - TILE / 2.0:
		player.die()
	# Don't let the puffin walk off the left edge of the course.
	if player.global_position.x < 6.0:
		player.global_position.x = 6.0
		player.velocity.x = maxf(player.velocity.x, 0.0)

func _on_player_died() -> void:
	if has_node("/root/GameState") and not get_node("/root/GameState").lose_life():
		_game_over = true

func _on_player_respawned() -> void:
	if _game_over:
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)

## Called by the goal (also usable from tests). Advances GameState and loads the next course.
func _on_goal() -> void:
	if _clearing:
		return
	_clearing = true
	level_cleared.emit()
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	AudioBridge.play_sfx("powerup")
	var n := int(level_id.split("-")[1])
	var last := n >= LAST_LEVEL
	_show_banner("WORLD 1 CLEAR!" if last else "COURSE CLEAR!")
	if has_node("/root/GameState"):
		get_node("/root/GameState").add_score(CLEAR_BONUS)
	await get_tree().create_timer(CLEAR_DELAY * (2.0 if last else 1.0)).timeout
	advance()

func advance() -> void:
	var n := int(level_id.split("-")[1])
	if n >= LAST_LEVEL:
		get_tree().change_scene_to_file(TITLE_SCENE)
		return
	if has_node("/root/GameState"):
		get_node("/root/GameState").set_level(1, n + 1)
	get_tree().change_scene_to_file(SCENE_PATH)

func _show_banner(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	var lbl := PixelLabel.new()
	lbl.text = text
	lbl.pixel_scale = 2
	lbl.color = Color8(255, 220, 96)
	lbl.position = Vector2((256 - PixelFont.text_width(text, 2)) / 2, 90)
	layer.add_child(lbl)
	add_child(layer)

## Simple original parallax-free sky: banded gradient + distant sea line.
class _Backdrop extends Node2D:
	var level_size := Vector2.ZERO
	func _draw() -> void:
		var top := Color8(88, 144, 224)
		var bottom := Color8(176, 216, 248)
		for i in 14:
			draw_rect(Rect2(0, i * 16, level_size.x, 16), top.lerp(bottom, i / 13.0))
		draw_rect(Rect2(0, 176, level_size.x, 48), Color8(56, 112, 184))
		for x in range(0, int(level_size.x), 48):
			draw_rect(Rect2(x + 8, 180 + (x / 48 % 3) * 8, 12, 1), Color8(120, 176, 232))
