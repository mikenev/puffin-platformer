extends SceneTree
## Headless regression tests for AudioManager music fades.
## Run: godot --headless --path . -s res://tests/test_audio_manager.gd   (exit code 0 = pass)

var am: Node
var failures := 0

func check(cond: bool, msg: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1

func wait(t: float) -> void:
	await create_timer(t).timeout

func players_on(track: String) -> Array:
	var s = load("res://audio/music/%s.ogg" % track)
	return [am._music_a, am._music_b].filter(func(p): return p.playing and p.stream == s)

func fresh() -> void:
	if am:
		am.queue_free()
		await process_frame
	am = load("res://scripts/audio_manager.gd").new()
	root.add_child(am)
	await process_frame

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# 1) World 1 -> title -> back to World 1 mid-crossfade: same player, position kept, no -60 dB jump.
	print("Scenario 1: interrupt crossfade back to the previous track")
	await fresh()
	am.play_music("world1_theme", 0.0)
	await wait(1.0)
	am.play_music("title_theme", 1.0)
	await wait(0.5)
	var w1: AudioStreamPlayer = players_on("world1_theme")[0]
	var pos_before := w1.get_playback_position()
	var vol_before := w1.volume_db
	am.play_music("world1_theme", 0.5)
	check(players_on("world1_theme").size() == 1 and players_on("world1_theme")[0] == w1, "World 1 continues on the same player")
	check(is_equal_approx(w1.volume_db, vol_before) and vol_before > -59.0, "fades up from current volume (%.1f dB), not -60" % vol_before)
	await process_frame
	check(w1.get_playback_position() >= pos_before - 0.05 and pos_before > 1.0, "position kept (%.2fs -> %.2fs)" % [pos_before, w1.get_playback_position()])
	await wait(0.7)
	check(w1.playing and is_equal_approx(w1.volume_db, 0.0), "World 1 back at 0 dB")
	check(players_on("title_theme").is_empty(), "title faded out and stopped")

	# 2) play_music on the same track during a stop fade-out: no second copy (no flam).
	print("Scenario 2: re-play the same track during stop_music fade")
	await fresh()
	am.play_music("world1_theme", 0.0)
	await wait(0.5)
	am.stop_music(1.0)
	await wait(0.3)
	var p2: AudioStreamPlayer = players_on("world1_theme")[0]
	var pos2 := p2.get_playback_position()
	am.play_music("world1_theme", 0.3)
	await process_frame
	check(players_on("world1_theme").size() == 1, "exactly one World 1 player")
	check(p2.playing and p2.get_playback_position() >= pos2 - 0.05, "position kept (%.2fs)" % pos2)
	check(not am._other(p2).playing, "other player silent")
	await wait(0.5)
	check(is_equal_approx(p2.volume_db, 0.0) and am.current_music == "world1_theme", "back at 0 dB")

	# 3) stop_music during a crossfade fades both players from their current volumes.
	print("Scenario 3: stop_music during crossfade")
	await fresh()
	am.play_music("world1_theme", 0.0)
	await wait(0.5)
	am.play_music("title_theme", 1.0)
	await wait(0.5)
	var out_p: AudioStreamPlayer = players_on("world1_theme")[0]
	var in_p: AudioStreamPlayer = players_on("title_theme")[0]
	var v_out := out_p.volume_db
	var v_in := in_p.volume_db
	am.stop_music(0.5)
	check(out_p.playing and in_p.playing, "neither track hard-stopped (out %.1f dB, in %.1f dB)" % [v_out, v_in])
	await wait(0.2)
	check(out_p.volume_db < v_out and in_p.volume_db < v_in, "both fading down from current volumes")
	await wait(0.5)
	check(not out_p.playing and not in_p.playing, "both stopped after fade")

	# 4) Bus API warns on an invalid bus name instead of failing silently.
	print("Scenario 4: invalid bus name")
	am.set_bus_mute("NoSuchBus", true)
	check(am.get_bus_volume("Music") > 0.0, "valid bus still works")

	am.queue_free()
	await process_frame
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)
