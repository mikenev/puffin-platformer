class_name Enemy
extends CharacterBody2D
## Walking ground enemy ("Snapper" crab). Patrols, turns at walls and ledges.
## Touching it from the side/below hurts the puffin; landing on it from above stomps it.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const SIZE := Vector2(12, 10)       ## body and hurt box
const SPRITE_Y := -3.0               ## sprite art sits in the lower part of the 16x16 frame
const LEDGE_PROBE := Vector2(8, 10)  ## ahead/below offset checked for floor before walking on
const STOMP_TOLERANCE := 4.0         ## px: puffin feet must be at most this far below enemy top
const SQUASH_TIME := 0.35

@export var speed := 28.0
@export var gravity := 900.0
var dir := -1
## Patrol bounds in px (left/right edge the body may reach); INF = only walls/ledges.
var patrol_min_x := -INF
var patrol_max_x := INF
var squashed := false
var _sprite := AnimatedSprite2D.new()

func _ready() -> void:
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = SIZE
	cs.shape = r
	add_child(cs)
	add_to_group("enemies")
	_sprite.sprite_frames = EnemySprite.build()
	_sprite.position.y = SPRITE_Y
	add_child(_sprite)
	_sprite.play("walk")

func _physics_process(delta: float) -> void:
	if squashed:
		return
	velocity.y = minf(velocity.y + gravity * delta, 300.0)
	if is_on_floor() and (is_on_wall() or not _floor_ahead()):
		dir = -dir
	if dir < 0 and global_position.x - SIZE.x / 2.0 <= patrol_min_x:
		dir = 1
	elif dir > 0 and global_position.x + SIZE.x / 2.0 >= patrol_max_x:
		dir = -1
	velocity.x = speed * dir
	move_and_slide()
	_sprite.flip_h = dir > 0

func _floor_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(LEDGE_PROBE.x * dir, LEDGE_PROBE.y)
	q.collision_mask = LAYER_WORLD
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

func rect() -> Rect2:
	return Rect2(global_position - SIZE / 2.0, SIZE)

## Called by the puffin each physics frame it overlaps this enemy. `prev_feet` and `prev_vy`
## are the puffin's feet y and vertical speed *before* this frame's move, so a fast fall that
## lands inside the enemy in one step still counts as coming from above.
func touch(p: Puffin, prev_feet: float, prev_vy: float) -> void:
	if squashed or p.is_dying():
		return
	if prev_vy > 0.0 and prev_feet <= rect().position.y + STOMP_TOLERANCE:
		stomp(p)
	else:
		p.hurt()

func stomp(p: Puffin) -> void:
	squashed = true
	collision_layer = 0
	_sprite.play("squash")
	Sfx.play("stomp")
	p.stomp_bounce()
	get_tree().create_timer(SQUASH_TIME).timeout.connect(queue_free)
