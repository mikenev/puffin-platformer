class_name Flyer
extends Enemy
## Gull: flies back and forth between patrol_min_x/patrol_max_x with a sine bob, ignoring
## gravity and terrain. Stompable from above like the crab (same touch()/stomp()).

const BOB_HEIGHT := 8.0
const BOB_SPEED := 2.5
var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	super._ready()
	collision_mask = 0  # flies through terrain
	speed = 32.0
	_base_y = position.y

func _frames() -> SpriteFrames:
	return EnemySprite.build_gull()

func _physics_process(delta: float) -> void:
	if squashed:
		return
	_t += delta
	if dir < 0 and global_position.x - SIZE.x / 2.0 <= patrol_min_x:
		dir = 1
	elif dir > 0 and global_position.x + SIZE.x / 2.0 >= patrol_max_x:
		dir = -1
	position.x += speed * dir * delta
	position.y = _base_y + sin(_t * BOB_SPEED) * BOB_HEIGHT
	_sprite.flip_h = dir > 0
