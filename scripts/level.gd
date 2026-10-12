extends Node2D
## Gray-box test level built from an ASCII map. Each '#' is a 16x16 solid tile.
## '=' is a one-way platform, 'P' is the player spawn.

const TILE := 16
const MAP := [
	"................................................................................................................................................",
	"................................................................................................................................................",
	"................................................................................................................................................",
	"................................................................................................................................................",
	"......................................................................####.....................................................................",
	"...............................................................................................................................................#",
	"..........................===.........................####.............................#......................................................#",
	"...................................................................................##..........................................................#",
	"................####...........................######..........................###......................................................####...#",
	".........................................####..............................####...........................................................#####..#",
	"............................................................................................................................................######.#",
	".P..........................######.....................................................................................................#######..#",
	"#########################.....##########....##########.....######################.....##############################################################",
	"#########################.....##########....##########.....######################.....##############################################################",
]

const COLORS := {"#": Color8(96, 96, 108), "=": Color8(150, 120, 90)}
var level_size := Vector2.ZERO

func _ready() -> void:
	level_size = Vector2(MAP[0].length() * TILE, MAP.size() * TILE)
	var spawn := Vector2(TILE * 2, TILE * 10)
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
	var player := Puffin.new()
	player.name = "Puffin"
	player.position = spawn
	add_child(player)
	var cam := FollowCamera.new()
	cam.target = player
	cam.limit_left = 0
	cam.limit_top = -TILE * 6
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)
	add_child(cam)
	cam.make_current()
	player.died.connect(cam.snap_to_target)
	cam.snap_to_target()
	_add_hud()

func _add_block(r: Rect2, kind: String) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size if kind == "#" else Vector2(r.size.x, 4)
	cs.shape = shape
	if kind == "=":
		cs.one_way_collision = true
		cs.position.y = -r.size.y / 2.0 + 2
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = COLORS[kind]
	vis.size = r.size if kind == "#" else Vector2(r.size.x, 6)
	vis.position = -r.size / 2.0
	body.add_child(vis)
	add_child(body)

func _draw() -> void:
	# Tile grid lines on solid ground for readability.
	for y in MAP.size():
		for x in MAP[y].length():
			if MAP[y][x] == "#":
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color8(70, 70, 82), false, 1.0)

func _add_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.name = "Hud"
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 8)
	label.text = "PUFFIN M1  arrows/WASD move  Z/space jump  X/shift run"
	layer.add_child(label)
	add_child(layer)

func _physics_process(_delta: float) -> void:
	var p: Puffin = $Puffin
	if p.global_position.y > level_size.y + 32 or Input.is_action_just_pressed("restart"):
		p.respawn()
