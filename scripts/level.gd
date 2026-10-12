extends Node2D
## Gray-box test level built from an ASCII map. Each '#' is a 16x16 solid tile.
## '=' is a one-way platform, 'P' is the player spawn.

const TILE := 16
const MAP := [
	".....................................................................................................................................................#",
	".....................................................................................................................................................#",
	".....................................................................................................................................................#",
	".....................................................................................................................................................#",
	".....................................................................................................................................................#",
	".........................................................................####........................................................................#",
	".......................................................####.............................#............................................................#",
	"......................===...........................................................##...............................................................#",
	"................................................######.........................###.........................................................###########",
	"................####.....................####...............................####..........................................................############",
	".........................................................................................................................................#############",
	".P.............................######...................................................................................................##############",
	"##########################...###########....##########.....#######################.....###############################################################",
	"##########################...###########....##########.....#######################.....###############################################################",
]

const COLORS := {"#": Color8(96, 96, 108), "=": Color8(150, 120, 90)}
const GRID_COLOR := Color8(70, 70, 82)
const ONE_WAY_THICKNESS := 6.0          ## visual and collision height of '=' platforms
const DEFAULT_SPAWN_TILE := Vector2i(2, 10)
const CAMERA_HEADROOM_TILES := 6        ## camera may scroll this many tiles above row 0
const FALL_DEATH_MARGIN := 32.0         ## px below the level before the puffin respawns
const HUD_TEXT := "M1 move:arrows run:X jump:Z R:reset"

var level_size := Vector2.ZERO
var _player: Puffin

func _ready() -> void:
	var width := 0
	for row: String in MAP:
		width = maxi(width, row.length())
	for i in MAP.size():
		if MAP[i].length() != width:
			# push_error survives release builds (assert is stripped there); row is treated as '.'-padded.
			push_error("MAP row %d is %d wide, expected %d" % [i, MAP[i].length(), width])
			assert(false)
	level_size = Vector2(width * TILE, MAP.size() * TILE)
	var spawn := Vector2(DEFAULT_SPAWN_TILE * TILE)
	for y in MAP.size():
		var row: String = MAP[y]
		var x := 0
		while x < row.length():
			var c := row[x]
			if c == "P":
				spawn = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			if c == "#" or c == "=":
				var start := x
				while x < row.length() and row[x] == c:
					x += 1
				_add_block(Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE), c)
				continue
			x += 1
	_player = Puffin.new()
	_player.name = "Puffin"
	_player.position = spawn
	add_child(_player)
	var cam := FollowCamera.new()
	cam.target = _player
	cam.limit_left = 0
	cam.limit_top = -TILE * CAMERA_HEADROOM_TILES
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	cam.make_current()
	_player.died.connect(cam.snap_to_target)
	_player.reset.connect(cam.snap_to_target)
	cam.snap_to_target()
	_add_hud()

func _add_block(r: Rect2, kind: String) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var vis_size := r.size if kind == "#" else Vector2(r.size.x, ONE_WAY_THICKNESS)
	shape.size = vis_size
	cs.shape = shape
	if kind == "=":
		cs.one_way_collision = true
		cs.position.y = -r.size.y / 2.0 + ONE_WAY_THICKNESS / 2.0
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = COLORS[kind]
	vis.size = vis_size
	vis.position = -r.size / 2.0
	body.add_child(vis)
	if kind == "#":
		# Tile grid drawn above the block fill so each tile stays readable.
		var grid := TileGrid.new()
		grid.size = r.size
		grid.position = -r.size / 2.0
		grid.color = GRID_COLOR
		grid.tile = TILE
		body.add_child(grid)
	add_child(body)

class TileGrid extends Node2D:
	var size := Vector2.ZERO
	var color := Color.BLACK
	var tile := 16
	func _draw() -> void:
		for x in int(size.x / tile):
			for y in int(size.y / tile):
				# Top and left edge only, so shared borders stay 1 px wide.
				var o := Vector2(x * tile, y * tile)
				draw_line(o + Vector2(0, 0.5), o + Vector2(tile, 0.5), color, 1.0)
				draw_line(o + Vector2(0.5, 0), o + Vector2(0.5, tile), color, 1.0)
		# Block outline closes the right and bottom edges.
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), color, false, 1.0)

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.name = "Hud"
	label.position = Vector2(4, 212)  # bottom: top row is the GameHud
	label.add_theme_font_size_override("font_size", 8)
	label.text = HUD_TEXT
	layer.add_child(label)
	add_child(layer)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_player.respawn(false)
	elif _player.global_position.y > level_size.y + FALL_DEATH_MARGIN:
		if has_node("/root/GameState") and not GameState.lose_life():
			get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
			return
		_player.respawn(true)
