class_name FollowCamera
extends Camera2D
## Smooth follow with horizontal look-ahead in the facing/moving direction, clamped to level limits.

@export var target: Node2D
@export var look_ahead := 40.0
@export var look_ahead_speed := 3.0
@export var vertical_offset := -16.0
var _ahead := 0.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	limit_smoothed = true

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var want := 0.0
	if target is Puffin:
		var p := target as Puffin
		want = look_ahead * p.facing * clampf(absf(p.velocity.x) / p.walk_speed, 0.0, 1.0)
	_ahead = lerpf(_ahead, want, clampf(look_ahead_speed * delta, 0.0, 1.0))
	global_position = target.global_position + Vector2(_ahead, vertical_offset)

func snap_to_target() -> void:
	_ahead = 0.0
	global_position = target.global_position + Vector2(0, vertical_offset)
	reset_smoothing()
