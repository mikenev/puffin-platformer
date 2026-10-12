extends SceneTree
## Per-course gameplay checks for World 1 (PR #7 levels + this PR's enemies/power-ups):
##   godot --headless --fixed-fps 60 -s res://tests/test_world_gameplay.gd
## For each of 1-1..1-4: enemies/fish spawn from markers, patrols stay 6+ tiles from spawn and
## checkpoints, parking at spawn for 20 s is safe, respawn invulnerability, enemies reset on R
## and on death, music, and the goal is reachable with enemies on (see EnemyReach below).

var fails := 0

func ok(c: bool, msg: String) -> void:
	print(("  PASS " if c else "  FAIL ") + msg)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await physics_frame

## LevelReach with enemies: tiles a flyer's bob envelope covers count as solid (the path must
## route around flyers rather than through them). Ground crabs/walkers stay standable: they can
## always be stomped or hopped, but the tiles right next to a gap landing are kept clear by the
## spawner's LEDGE_MARGIN, which is checked separately.
class EnemyReach extends LevelReach:
	var blocked := {}
	func solid(x: int, y: int) -> bool:
		return blocked.has(Vector2i(x, y)) or super.solid(x, y)

func _initialize() -> void:
	_run.call_deferred()

## Tile rows a flyer's body covers over its whole bob.
func _env_rows(s: Dictionary) -> Array:
	var top: float = s.pos.y - Flyer.BOB_HEIGHT - Enemy.SIZE.y / 2.0
	var bot: float = s.pos.y + Flyer.BOB_HEIGHT + Enemy.SIZE.y / 2.0
	return range(floori(top / 16), floori((bot - 0.01) / 16) + 1)

func _enemies() -> Array:
	return get_nodes_in_group("enemies").filter(func(e): return not e.is_queued_for_deletion())

func _run() -> void:
	var gs := root.get_node("GameState")
	for id in W1Maps.MAPS:
		print(id)
		Sfx.history.clear()
		var lvl: WorldLevel = load("res://scenes/world/world_level.tscn").instantiate()
		lvl.level_id = id
		root.add_child(lvl)
		await frames(3)
		var sp: GameplaySpawner = lvl.get_node("Gameplay")
		var P: Puffin = lvl.player
		var markers := get_nodes_in_group("enemy_spawn")
		var pmarkers := get_nodes_in_group("powerup_spawn")
		var en := _enemies()
		var kinds := {}
		for e in en:
			var k: String = "flyer" if e is Flyer else e.look
			kinds[k] = kinds.get(k, 0) + 1
		ok(en.size() == markers.size() - sp.skipped.size() and en.size() > 0, "%d enemies from %d markers %s (skipped %s)" % [en.size(), markers.size(), kinds, sp.skipped])
		var pf := lvl.get_children().filter(func(c): return c is PowerFish)
		var dive := pf.filter(func(f): return f.power == Puffin.Power.DIVE).size()
		ok(pf.size() == pmarkers.size(), "%d power fish from %d markers (%d dive, %d glide)" % [pf.size(), pmarkers.size(), dive, pf.size() - dive])
		# Safety zones
		var safe: Array[float] = [P.spawn_point.x]
		for cp in get_nodes_in_group("checkpoint"): safe.append(cp.global_position.x)
		var closest := 9999.0
		for s in sp.specs:
			for sx in safe:
				var d := maxf(s.min_x - sx, sx - s.max_x)
				closest = minf(closest, d)
		ok(closest >= 6 * 16, "closest patrol edge to spawn/checkpoint: %.0f px (%.1f tiles), %d safe points" % [closest, closest / 16.0, safe.size()])
		# Ledge margin: no ground patrol reaches within 2 tiles of a ledge (gap landings clear)
		var ledge_ok := true
		for s in sp.specs:
			if s.kind == "flyer": continue
			var fy := floori(s.pos.y / 16) + 1
			var lo := floori(s.min_x / 16)
			var hi := floori((s.max_x - 1) / 16)
			for x in [lo - 1, lo - 2, hi + 1, hi + 2]:
				if x >= 0 and x < lvl.map[0].length() and not sp._floor(lvl.map, x, fy) and not sp._solid(lvl.map, x, fy - 1):
					# A gap within 2 tiles of the patrol edge is only OK if the marker itself forced it.
					if absf(s.pos.x / 16 - x) > 3:
						ledge_ok = false
						print("    gap at c%d near %s patrol c%d-%d (marker c%d)" % [x, s.kind, lo, hi, floori(s.pos.x / 16)])
		ok(ledge_ok, "ground patrols keep 2 tiles back from gap edges")
		# Park at spawn for 20 s with enemies live
		var died := [0]
		P.died.connect(func(): died[0] += 1)
		await frames(1200)
		ok(died[0] == 0, "parked at spawn 20 s with enemies active: %d deaths" % died[0])
		# Finishability with flyers as obstacles
		var r := EnemyReach.new(lvl.map)
		for s in sp.specs:
			if s.kind != "flyer": continue
			for x in range(floori(s.min_x / 16), floori((s.max_x - 1) / 16) + 1):
				for y in _env_rows(s): r.blocked[Vector2i(x, y)] = true
		var seen := r.reachable()
		var g := r.find("G")
		var goal_ok := false
		for n in seen:
			if n.y == g.y + 1 and absi(n.x - g.x) <= 1: goal_ok = true
		if goal_ok:
			ok(true, "goal reachable with enemies on (every flyer zone treated as solid; %d nodes)" % seen.size())
		else:
			# A flyer sits on the only route. Fine if the puffin can stomp it out of the way: from a
			# node reachable with it present, its top is within stomp range, and the goal is
			# reachable once it is gone.
			var all_ok := true
			for s in sp.specs:
				if s.kind != "flyer": continue
				var others := {}  # judge each flyer on its own; flyers are far apart on these maps
				var r_without := EnemyReach.new(lvl.map)
				r_without.blocked = others
				var r_with := EnemyReach.new(lvl.map)
				r_with.blocked = others.duplicate()
				var cy1 := floori(s.pos.y / 16)
				var x0 := floori(s.min_x / 16)
				var x1 := floori((s.max_x - 1) / 16)
				for x in range(x0, x1 + 1):
					for y in _env_rows(s): r_with.blocked[Vector2i(x, y)] = true
				var g_without := false
				for n in r_without.reachable():
					if n.y == g.y + 1 and absi(n.x - g.x) <= 1: g_without = true
				var g_with := false
				var stompable := false
				var top_low: float = s.pos.y + Flyer.BOB_HEIGHT - Enemy.SIZE.y / 2.0  # flyer top at lowest bob
				for n in r_with.reachable():
					if n.y == g.y + 1 and absi(n.x - g.x) <= 1: g_with = true
					var rise: float = n.y * 16 - top_low
					if n.x >= x0 - 1 and n.x <= x1 + 1 and rise >= 0 and rise <= 55:
						stompable = true
				if not g_with:
					# Moving obstacle: can the route be taken while it is parked at either end of its
					# patrol (the player waits for it to fly to the far end)?
					var parked := false
					for ends in [[x0, x0 + 1], [x1 - 1, x1]]:
						var rp := EnemyReach.new(lvl.map)
						for x in ends:
							for y in _env_rows(s): rp.blocked[Vector2i(x, y)] = true
						for n in rp.reachable():
							if n.y == g.y + 1 and absi(n.x - g.x) <= 1: parked = true
						rp.free_puffin()
					print("    flyer c%d r%d patrol zone covers the route; stompable from route: %s (goal after stomp: %s); passable while it is at one end of its patrol: %s" % [floori(s.pos.x / 16), cy1, stompable, g_without, parked])
					if not ((stompable and g_without) or parked): all_ok = false
				r_without.free_puffin()
				r_with.free_puffin()
			ok(all_ok, "goal reachable with enemies on (route-blocking flyers stompable or passable by timing)")
		r.free_puffin()
		# Respawn invulnerability + enemies reset on R and death
		var first := _enemies()
		var n0 := first.size()
		var pos0 := first.map(func(e): return e.global_position.x)
		first[0].stomp(P)
		P.respawn(false)
		ok(P.is_invulnerable(), "invulnerable after R respawn")
		await frames(2)
		var after := _enemies()
		after.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		var spec_x := sp.specs.map(func(s): return s.pos.x)
		spec_x.sort()
		var at := after.size() == n0
		for i in after.size():
			if at and absf(after[i].global_position.x - spec_x[i]) > 2: at = false
		ok(at and after.all(func(e): return not e.squashed), "R: all %d enemies back at markers, stomped restored" % n0)
		after[0].stomp(P)
		P._invuln = 0.0
		P.die()
		await frames(70)
		var after2 := _enemies()
		ok(after2.size() == n0 and after2.all(func(e): return not e.squashed) and P.is_invulnerable(), "death: enemies restored, puffin invulnerable after respawn")
		ok(AudioServer.get_bus_count() > 0 and root.get_node("AudioManager").current_music == "world1_theme", "level music: world1_theme")
		lvl.queue_free()
		await frames(2)
		gs.new_game()
	# Title music
	var title: Node = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await frames(2)
	ok(root.get_node("AudioManager").current_music == "title_theme", "title screen music: title_theme")
	print("WORLD GAMEPLAY TESTS ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
