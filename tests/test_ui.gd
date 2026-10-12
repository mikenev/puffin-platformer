extends SceneTree
## Headless smoke test: godot --headless -s tests/test_ui.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gs := root.get_node("GameState")
	var ok := true
	gs.new_game()
	gs.add_fish(105)
	ok = ok and gs.fish == 5 and gs.lives == 4 and gs.score == 1050
	gs.set_music_volume(0.5)
	ok = ok and gs.music_volume == 0.5
	change_scene_to_file("res://scenes/ui/title.tscn")
	await process_frame
	await process_frame
	ok = ok and current_scene.name == "Title"
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var pm := current_scene.get_node("PauseMenu")
	pm.set_open(true)
	ok = ok and paused
	pm.set_open(false)
	ok = ok and not paused
	for ev in InputMap.action_get_events("pause"):
		if ev is InputEventKey and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			ok = false
	gs.lose_life()
	ok = ok and gs.lives == 3
	print("UI TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
