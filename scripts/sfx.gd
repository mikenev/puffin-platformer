class_name Sfx
## Thin wrapper over the AudioManager autoload (PR #3) so gameplay code has one call site,
## and tests can read `Sfx.history` to confirm which sounds fired.

static var history: Array[String] = []

static func play(sfx_name: String, pitch := 1.0) -> void:
	history.append(sfx_name)
	var am := _manager()
	if am:
		am.play_sfx(sfx_name, pitch)

static func music(track_name: String) -> void:
	history.append("music:" + track_name)
	var am := _manager()
	if am:
		am.play_music(track_name)

static func _manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree else null
