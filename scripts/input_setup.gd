extends Node
## Registers the input map at startup (keyboard + gamepad) so bindings live in one readable place.

const KEYS := {
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"jump": [KEY_SPACE, KEY_Z, KEY_UP, KEY_W],
	"run": [KEY_SHIFT, KEY_X],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
}
const DEADZONE := 0.25
const PAD := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A],
	"run": [JOY_BUTTON_X, JOY_BUTTON_B],
	"restart": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
}

func _ready() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in PAD[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	for pair in [["move_left", -1.0], ["move_right", 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_LEFT_X
		m.axis_value = pair[1]
		InputMap.action_add_event(pair[0], m)
