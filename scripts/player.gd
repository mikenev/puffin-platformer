class_name Puffin
extends CharacterBody2D
## Puffin player controller: SMB-style momentum, variable jump, coyote time, jump buffer.
## Units: pixels and seconds. All tuning values are exported.

signal died

@export_group("Run")
@export var walk_speed := 90.0
@export var run_speed := 150.0
@export var ground_accel := 420.0
@export var ground_decel := 520.0
@export var skid_decel := 900.0        ## when pressing opposite to motion
@export var air_accel := 300.0
@export var air_decel := 120.0
@export_group("Jump")
@export var jump_velocity := -330.0
@export var run_jump_bonus := -25.0    ## extra launch at full run speed
@export var gravity_rise := 820.0      ## while ascending with jump held
@export var gravity_fall := 1300.0     ## while descending
@export var jump_cut_multiplier := 0.45 ## upward velocity kept when jump released early
@export var max_fall_speed := 300.0
@export var coyote_time := 0.09
@export var jump_buffer_time := 0.11

## Future power-ups (colored fish) hook in here. Abilities may override movement per state.
enum Power { NONE, DIVE, GLIDE }
var power: Power = Power.NONE

var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
var spawn_point := Vector2.ZERO
@onready var sprite: AnimatedSprite2D = AnimatedSprite2D.new()

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 13)
	shape.shape = rect
	shape.position = Vector2(0, 1.5)
	add_child(shape)
	sprite.sprite_frames = PuffinSprite.build()
	sprite.position = Vector2(1, 0)
	add_child(sprite)
	sprite.play("idle")
	floor_snap_length = 4.0
	spawn_point = global_position

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var running := Input.is_action_pressed("run")
	_update_horizontal(dir, running, delta)
	_update_timers(delta)
	_update_jump()
	_apply_gravity(delta)
	move_and_slide()
	if is_on_ceiling() and velocity.y < 0:
		velocity.y = 0
	_update_animation(dir)

func _update_horizontal(dir: float, running: bool, delta: float) -> void:
	var top := run_speed if running else walk_speed
	var on_floor := is_on_floor()
	if dir != 0.0:
		facing = signi(int(sign(dir)))
		var target := dir * top
		var accel := ground_accel if on_floor else air_accel
		if on_floor and sign(velocity.x) != 0 and sign(velocity.x) != sign(dir):
			accel = skid_decel
		# Above top speed (released run): bleed off gently instead of snapping.
		if absf(velocity.x) > top and sign(velocity.x) == sign(dir):
			accel = ground_decel * 0.5 if on_floor else 0.0
		velocity.x = move_toward(velocity.x, target, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (ground_decel if on_floor else air_decel) * delta)

func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
		_jumping = false
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer_time
	else:
		_buffer -= delta

func _update_jump() -> void:
	if _buffer > 0.0 and _coyote > 0.0:
		var speed_ratio := clampf(absf(velocity.x) / run_speed, 0.0, 1.0)
		velocity.y = jump_velocity + run_jump_bonus * speed_ratio
		_jumping = true
		_buffer = 0.0
		_coyote = 0.0
	# Variable height: releasing jump while rising cuts upward velocity.
	if _jumping and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		_jumping = false

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := gravity_fall
	if velocity.y < 0.0 and Input.is_action_pressed("jump"):
		g = gravity_rise
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

func _update_animation(dir: float) -> void:
	sprite.flip_h = facing < 0
	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif absf(velocity.x) > 5.0:
		sprite.play("run")
		sprite.speed_scale = clampf(absf(velocity.x) / walk_speed, 0.6, 2.0)
	else:
		sprite.play("idle")

func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	died.emit()
