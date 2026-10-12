class_name AudioBridge
extends RefCounted
## Talks to the AudioManager autoload (PR #3) when present; otherwise falls back to AudioServer
## buses directly so menus work on branches without audio.

static func _am() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree else null

static func play_music(track: String) -> void:
	var am := _am()
	if am and am.has_method("play_music"):
		am.play_music(track)

static func play_sfx(sfx: String) -> void:
	var am := _am()
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx)

static func set_volume(bus: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	var am := _am()
	if am and am.has_method("set_bus_volume"):
		am.set_bus_volume(bus, linear)
	else:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
			AudioServer.set_bus_mute(i, linear <= 0.0)
