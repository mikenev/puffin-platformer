class_name FishPickup
extends Area2D
## Bobbing colored-fish power-up. Blue = DIVE, green = GLIDE (see Puffin.Power).

const BOB_HEIGHT := 3.0
const BOB_SPEED := 3.0
const COLORS := {Puffin.Power.DIVE: Color8(64, 128, 248), Puffin.Power.GLIDE: Color8(64, 200, 96)}
const ART := [
	"............",
	"....FFFF..T.",
	"..FFFFFFFTT.",
	".FEFFFFFFTT.",
	".FFFFFFFFFT.",
	"..FFFFFFFTT.",
	"....FFFF..T.",
	"............",
]

@export var power: Puffin.Power = Puffin.Power.DIVE
var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = Enemy.LAYER_PLAYER
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 10)
	cs.shape = r
	add_child(cs)
	var s := Sprite2D.new()
	s.texture = _tex(COLORS.get(power, Color.WHITE))
	add_child(s)
	_base_y = position.y
	body_entered.connect(_on_body)

static func _tex(c: Color) -> ImageTexture:
	var img := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 12:
			var ch: String = ART[y][x]
			var col := Color(0, 0, 0, 0)
			if ch == "F": col = c
			elif ch == "T": col = c.darkened(0.3)
			elif ch == "E": col = Color8(8, 8, 8)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT

func _on_body(b: Node) -> void:
	if b is Puffin and not b.is_dying():
		b.collect_power(power)
		queue_free()
