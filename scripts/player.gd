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

## Colored-fish power-ups: PowerFish calls collect_power(). DIVE = blue fish (down in the air
## dives straight down and stomps), GLIDE = green fish (hold jump while falling to glide).
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

@export_group("Power-ups")
@export var dive_speed := 360.0          ## DIVE: fall speed while diving (down in the air)
@export var glide_fall_speed := 45.0     ## GLIDE: max fall speed while holding jump
@export var glide_gravity := 500.0
@export var stomp_bounce_velocity := -200.0
@export var stomp_bounce_held := -320.0  ## bounce when jump is held on stomp
@export var hurt_invuln_time := 1.5
@export var respawn_invuln_time := 1.5
const POWER_TINT := {0: Color.WHITE, 1: Color8(150, 190, 255), 2: Color8(160, 255, 170)}
const FLICKER_HZ := 15.0
var diving := false
var gliding := false
var _invuln := 0.0
var _was_on_floor := true
var _was_skidding := false
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
	# Layer 1 too, so #7's fish, checkpoint and goal Areas (default mask 1) still detect the puffin.
	collision_layer = Enemy.LAYER_WORLD | Enemy.LAYER_PLAYER
	collision_mask = Enemy.LAYER_WORLD
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
	if not diving:
		_update_horizontal(dir, running, delta)
	_update_timers(delta)
	_update_jump()
	_update_power(delta)
	if not diving:
		_apply_gravity(delta)
	var prev_feet := feet_y()
	var prev_vy := velocity.y
	move_and_slide()
	if is_on_ceiling() and velocity.y < 0:
		velocity.y = 0
	_check_enemies(prev_feet, prev_vy)
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		diving = false
		Sfx.play("land")
	_was_on_floor = on_floor
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
		Sfx.play("jump")
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
	var cap := max_fall_speed
	if gliding:
		g = glide_gravity
		cap = glide_fall_speed
	velocity.y = minf(velocity.y + g * delta, cap)

## Power-up movement. `power` is set by PowerFish via collect_power().
func _update_power(delta: float) -> void:
	gliding = power == Power.GLIDE and not is_on_floor() and velocity.y > 0.0 \
		and Input.is_action_pressed("jump")
	if power == Power.DIVE and not is_on_floor() and not diving \
			and Input.is_action_just_pressed("move_down"):
		diving = true
	if diving:
		velocity = Vector2(0.0, dive_speed)
	if _invuln > 0.0:
		_invuln -= delta
		sprite.visible = _invuln <= 0.0 or int(_invuln * FLICKER_HZ) % 2 == 0
	else:
		sprite.visible = true

func _check_enemies(prev_feet: float, prev_vy: float) -> void:
	var me := Rect2(global_position + HITBOX_OFFSET - HITBOX_SIZE / 2.0, HITBOX_SIZE)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.squashed and me.intersects(e.rect()):
			e.touch(self, prev_feet, prev_vy)
			if is_dying():
				return

func feet_y() -> float:
	return global_position.y + HITBOX_OFFSET.y + HITBOX_SIZE.y / 2.0

func is_invulnerable() -> bool:
	return _invuln > 0.0

func collect_power(p: Power) -> void:
	Sfx.play("collect_fish")
	set_power(p)
	Sfx.play("powerup")

func set_power(p: Power) -> void:
	power = p
	diving = false
	sprite.modulate = POWER_TINT[int(p)]

## Called by enemies on a side/below hit: lose the power-up, or die if already normal.
func hurt() -> void:
	if is_dying() or is_invulnerable():
		return
	if power != Power.NONE:
		Sfx.play("hurt")
		set_power(Power.NONE)
		_invuln = hurt_invuln_time
	else:
		die()  # death sound only; layering hurt on top of it muddies the cue

## Called by an enemy we landed on. Holding jump gives the higher bounce.
func stomp_bounce() -> void:
	diving = false
	velocity.y = stomp_bounce_held if Input.is_action_pressed("jump") else stomp_bounce_velocity
	_jumping = Input.is_action_pressed("jump")

func is_skidding(dir: float) -> bool:
	return is_on_floor() and absf(velocity.x) > SKID_MIN_SPEED and dir != 0.0 \
		and signf(dir) != signf(velocity.x)

func _update_animation(dir: float) -> void:
	var skid := is_skidding(dir)
	if skid and not _was_skidding:
		Sfx.play("skid")
	_was_skidding = skid
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
	Sfx.play("death")
	died.emit()

## Puts the puffin back at spawn. `fell` = true after the death animation, false for an
## instant R reset (emits `reset`). Always emits `respawned`.
func respawn(fell: bool = true) -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	_death_t = 0.0
	_invuln = respawn_invuln_time  # brief flicker so nothing can hit you right at spawn
	if fell:
		set_power(Power.NONE)
	_jumping = false
	_jump_cut_pending = false
	_buffer = 0.0
	_coyote = 0.0
	sprite.play("idle")
	if not fell:
		reset.emit()
	respawned.emit()
