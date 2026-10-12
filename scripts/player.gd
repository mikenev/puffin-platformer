class_name Puffin
extends CharacterBody2D
## Puffin player controller: SMB-style momentum, variable jump, coyote time, jump buffer.
## Units: pixels and seconds. All tuning values are exported.

signal died       ## fell in a pit (death animation starts)
signal reset      ## player pressed restart (instant)
signal respawned  ## puffin is back at spawn (after death or reset)

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

## Hook for the colored-fish power-ups (later milestones): each fish sets `power`,
## and movement code will branch on it (e.g. DIVE underwater, GLIDE slow fall). Unused in M1.
enum Power { NONE, DIVE, GLIDE }
var power: Power = Power.NONE

var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
var spawn_point := Vector2.ZERO
var _jump_cut_pending := false
var sprite := AnimatedSprite2D.new()
var _dust: CPUParticles2D

const HITBOX_SIZE := Vector2(10, 13)
const HITBOX_OFFSET := Vector2(0, 1.5)
const SPRITE_OFFSET := Vector2(1, 0)
const FLOOR_SNAP := 4.0
const OVERSPEED_DECEL_FACTOR := 0.5   ## fraction of ground_decel used when above top speed
const RUN_ANIM_MIN_SPEED := 5.0
const RUN_ANIM_SCALE := Vector2(0.75, 2.0)  ## min keeps the run cycle moving at low speed
const DEATH_TIME := 0.9
const DEATH_HOP := -260.0
var _death_t := 0.0
const SKID_MIN_SPEED := 40.0

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	shape.shape = rect
	shape.position = HITBOX_OFFSET
	add_child(shape)
	sprite.sprite_frames = load("res://art/puffin/puffin_frames.tres")
	sprite.position = SPRITE_OFFSET
	add_child(sprite)
	sprite.play("idle")
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(0, HITBOX_OFFSET.y + HITBOX_SIZE.y / 2.0)
	_dust.emitting = false
	_dust.amount = 6
	_dust.lifetime = 0.3
	_dust.direction = Vector2(0, -1)
	_dust.spread = 60.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 10.0
	_dust.initial_velocity_max = 25.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.0
	_dust.color = Color8(200, 200, 190)
	add_child(_dust)
	floor_snap_length = FLOOR_SNAP
	spawn_point = global_position

func _physics_process(delta: float) -> void:
	if _death_t > 0.0:
		# SMB-style death: pop up, then fall through everything, then respawn.
		_death_t -= delta
		velocity.y = minf(velocity.y + gravity_fall * delta, max_fall_speed)
		position += velocity * delta
		if _death_t <= 0.0:
			respawn(true)
		return
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
		facing = 1 if dir > 0.0 else -1
		var target := dir * top
		var accel := ground_accel if on_floor else air_accel
		if on_floor and signf(velocity.x) != 0.0 and signf(velocity.x) != signf(dir):
			accel = skid_decel
		# Above top speed (released run): bleed off gently instead of snapping.
		if absf(velocity.x) > top and signf(velocity.x) == signf(dir):
			accel = ground_decel * OVERSPEED_DECEL_FACTOR if on_floor else 0.0
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
		# Buffered jump whose button was already released: cut it right away (short hop).
		_jump_cut_pending = not Input.is_action_pressed("jump")
	# Variable height: releasing jump while rising cuts upward velocity.
	var cut := _jump_cut_pending or Input.is_action_just_released("jump")
	_jump_cut_pending = false
	if _jumping and cut and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		_jumping = false

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := gravity_fall
	if velocity.y < 0.0 and Input.is_action_pressed("jump"):
		g = gravity_rise
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

func is_skidding(dir: float) -> bool:
	return is_on_floor() and absf(velocity.x) > SKID_MIN_SPEED and dir != 0.0 \
		and signf(dir) != signf(velocity.x)

func _update_animation(dir: float) -> void:
	var skid := is_skidding(dir)
	_dust.emitting = skid
	# While skidding, `facing` already points toward the pressed direction (opposite the
	# slide), so the skid sprite looks the way the player is turning, like SMB's skid turn.
	sprite.flip_h = facing < 0
	sprite.position.x = SPRITE_OFFSET.x * facing
	if not is_on_floor():
		sprite.speed_scale = 1.0
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif skid:
		sprite.speed_scale = 1.0
		sprite.play("skid")
	elif absf(velocity.x) > RUN_ANIM_MIN_SPEED:
		sprite.speed_scale = clampf(absf(velocity.x) / walk_speed, RUN_ANIM_SCALE.x, RUN_ANIM_SCALE.y)
		sprite.play("run")
	else:
		sprite.speed_scale = 1.0
		sprite.play("idle")

func is_dying() -> bool:
	return _death_t > 0.0

## Pit death: emits `died`, plays the death animation, then respawns.
func die() -> void:
	if is_dying():
		return
	_death_t = DEATH_TIME
	velocity = Vector2(0.0, DEATH_HOP)
	_dust.emitting = false
	sprite.speed_scale = 1.0
	sprite.play("death")
	died.emit()

## Puts the puffin back at spawn. `fell` = true after the death animation, false for an
## instant R reset (emits `reset`). Always emits `respawned`.
func respawn(fell: bool = true) -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	_death_t = 0.0
	_jumping = false
	_jump_cut_pending = false
	_buffer = 0.0
	_coyote = 0.0
	sprite.play("idle")
	if not fell:
		reset.emit()
	respawned.emit()
