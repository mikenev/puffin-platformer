extends SceneTree
## World 1 course checks: godot --headless -s tests/test_levels.gd
## 1) every course builds (TileMapLayer, goal, spawn markers with "kind")
## 2) goal + fish are reachable with the real jump metrics (LevelReach)
## 3) goal flow advances GameState 1-1 -> 1-4 and 1-4 returns to title

var fails := 0

func check(cond: bool, msg: String) -> void:
	print(("  PASS " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gs := root.get_node("GameState")
	# Checker sanity: it must reject things the puffin can't do.
	var blank := ".".repeat(40)
	var gap_map: Array = []
	var wall_map: Array = []
	for y in 14:
		gap_map.append(blank)
		wall_map.append(blank)
	gap_map[11] = ".P" + ".".repeat(36) + "G."
	gap_map[12] = "#".repeat(12) + ".".repeat(9) + "#".repeat(19)
	gap_map[13] = gap_map[12]
	wall_map[11] = ".P" + ".".repeat(36) + "G."
	wall_map[12] = "#".repeat(40)
	wall_map[13] = wall_map[12]
	for y in range(6, 12):
		wall_map[y] = wall_map[y].substr(0, 20) + "#" + wall_map[y].substr(21)
	for pair in [["9-tile gap", gap_map], ["6-tile wall", wall_map]]:
		var rr := LevelReach.new(pair[1])
		var s2 := rr.reachable()
		check(not s2.has(Vector2i(38, 12)), "checker rejects " + pair[0])
		rr.free_puffin()
	for id in W1Maps.MAPS:
		print(id)
		var rows: Array = W1Maps.MAPS[id]
		var r := LevelReach.new(rows)
		var seen := r.reachable()
		var g := r.find("G")
		var goal_ok := false
		for n in seen:
			if n.y == g.y + 1 and absi(n.x - g.x) <= 1:
				goal_ok = true
		check(goal_ok, "goal reachable from spawn (%d standable nodes reached)" % seen.size())
		var fish := 0
		var fish_ok := 0
		var bad: Array = []
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "f":
					fish += 1
					if r.touched.has(Vector2i(x, y)):
						fish_ok += 1
					else:
						bad.append(Vector2i(x, y))
		check(fish_ok == fish, "fish reachable %d/%d %s" % [fish_ok, fish, str(bad) if bad else ""])
		r.free_puffin()
		# Build the real scene.
		var lvl: WorldLevel = load("res://scenes/world/world_level.tscn").instantiate()
		lvl.level_id = id
		root.add_child(lvl)
		await process_frame
		check(lvl.terrain.get_used_cells().size() > 100, "terrain TileMapLayer filled (%d cells)" % lvl.terrain.get_used_cells().size())
		check(lvl.get_node_or_null("Goal") != null, "goal present")
		var markers := get_nodes_in_group("enemy_spawn") + get_nodes_in_group("powerup_spawn")
		var kinds_ok := markers.all(func(m: Node) -> bool: return m is Marker2D and m.has_meta("kind"))
		check(markers.size() > 0 and kinds_ok, "%d spawn markers, all Marker2D with kind" % markers.size())
		check(get_nodes_in_group("fish").size() == fish, "fish pickups spawned (%d)" % fish)
		lvl.queue_free()
		await process_frame
	# Goal flow.
	gs.new_game()
	change_scene_to_file("res://scenes/world/world_level.tscn")
	for n in range(1, 5):
		await process_frame
		await process_frame
		var lvl := current_scene as WorldLevel
		check(lvl != null and lvl.level_id == "1-%d" % n and gs.level == n, "loaded 1-%d (HUD W %s)" % [n, gs.world_level_text()])
		lvl.advance()
	await process_frame
	await process_frame
	check(current_scene.name == "Title", "after 1-4 returns to title")
	print("LEVEL TESTS ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
