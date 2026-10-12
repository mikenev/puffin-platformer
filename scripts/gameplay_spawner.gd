class_name GameplaySpawner
extends Node
## Spawns enemies and fish power-ups from WorldLevel's Marker2D groups (PR #7) once
## `level_built` fires, and resets every enemy to its marker on death and on R.
##   enemy_spawn   kind: crab | walker | flyer  (optional meta: patrol_min / patrol_max, in tiles)
##   powerup_spawn kind: fish_power             (optional meta: power = "dive" | "glide";
##                 otherwise alternates dive/glide, offset by course number)
## Markers carry no patrol metadata today, so limits are derived from the map: walk until a wall
## or ledge (max MAX_RANGE tiles each way), stay LEDGE_MARGIN tiles back from ledges so gap
## landings are clear, and never come within SAFE_TILES of the spawn or any checkpoint.

const TILE := 16
const MAX_RANGE := 5
const LEDGE_MARGIN := 2
const FLYER_RANGE := 4
const SAFE_TILES := 6
const HEAD_CLEAR := 20.0   ## px kept between a flyer's lowest point and a surface below (puffin is 13 tall)

var level: Node
var specs: Array[Dictionary] = []   ## {kind, pos, min_x, max_x}; read by tests
var skipped: Array[String] = []     ## markers dropped because they sit inside a safe zone

func _ready() -> void:
	level = get_parent()
	if level.has_signal("level_built"):
		level.level_built.connect(_on_built)

func _on_built() -> void:
	var map: Array = level.map
	var safe: Array[float] = [level.player.spawn_point.x]
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		safe.append(cp.global_position.x)
	for m in get_tree().get_nodes_in_group("enemy_spawn"):
		var s := _spec(m, map, safe)
		if s.is_empty():
			skipped.append(m.name)
		else:
			specs.append(s)
	var fish := get_tree().get_nodes_in_group("powerup_spawn")
	fish.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	# No color metadata on #7's markers: alternate dive/glide, offset by course so each power
	# shows up across World 1 even when a course has a single fish marker.
	var offset := int(str(level.get("level_id")).get_slice("-", 1)) - 1 if level.get("level_id") else 0
	for i in fish.size():
		var m: Node2D = fish[i]
		var pf := PowerFish.new()
		var want: String = m.get_meta("power", "dive" if (i + offset) % 2 == 0 else "glide")
		pf.power = Puffin.Power.GLIDE if want == "glide" else Puffin.Power.DIVE
		pf.position = m.global_position
		level.add_child.call_deferred(pf)
	_spawn_enemies.call_deferred()
	level.player.respawned.connect(_reset)

func _solid(map: Array, x: int, y: int) -> bool:
	if y < 0 or y >= map.size() or x < 0 or x >= map[0].length():
		return x < 0 or x >= map[0].length()
	return "#S".contains(map[y][x])

func _floor(map: Array, x: int, y: int) -> bool:
	return _solid(map, x, y) or (y >= 0 and y < map.size() and x >= 0 and x < map[0].length() and map[y][x] == "=")

## How far to pull a patrol end back so a gap is at least LEDGE_MARGIN+1 tiles beyond it.
func _ledge_pull(map: Array, end: int, my: int, d: int) -> int:
	for k in range(1, LEDGE_MARGIN + 2):
		var x := end + d * k
		if _solid(map, x, my):
			return 0  # wall first: no gap on this side
		if not _floor(map, x, my + 1):
			return LEDGE_MARGIN + 1 - k
	return 0

func _spec(m: Node2D, map: Array, safe: Array[float]) -> Dictionary:
	var kind: String = m.get_meta("kind", "crab")
	var mx := floori(m.global_position.x / TILE)
	var my := floori(m.global_position.y / TILE)
	var lo := mx
	var hi := mx
	var pos := m.global_position
	if kind == "flyer":
		lo = maxi(0, mx - FLYER_RANGE)
		hi = mini(map[0].length() - 1, mx + FLYER_RANGE)
		# Never hover so low that a puffin standing on a platform below would touch it.
		for x in range(lo, hi + 1):
			for y in range(my + 1, mini(my + 4, map.size())):
				if _floor(map, x, y) and not _floor(map, x, y - 1):
					var limit := y * TILE - HEAD_CLEAR - Flyer.BOB_HEIGHT - Enemy.SIZE.y / 2.0
					pos.y = minf(pos.y, limit)
					break
	else:
		while mx - lo < MAX_RANGE and not _solid(map, lo - 1, my) and _floor(map, lo - 1, my + 1):
			lo -= 1
		while hi - mx < MAX_RANGE and not _solid(map, hi + 1, my) and _floor(map, hi + 1, my + 1):
			hi += 1
		# Keep LEDGE_MARGIN tiles between each patrol end and any gap (gap landings stay clear).
		lo = mini(lo + _ledge_pull(map, lo, my, -1), mx)
		hi = maxi(hi - _ledge_pull(map, hi, my, 1), mx)
		pos.y = (my + 1) * TILE - Enemy.SIZE.y / 2.0
	if m.has_meta("patrol_min"): lo = int(m.get_meta("patrol_min"))
	if m.has_meta("patrol_max"): hi = int(m.get_meta("patrol_max"))
	var min_x := float(lo * TILE)
	var max_x := float((hi + 1) * TILE)
	for sx in safe:
		var zl := sx - SAFE_TILES * TILE
		var zr := sx + SAFE_TILES * TILE
		if max_x <= zl or min_x >= zr:
			continue
		if pos.x >= sx: min_x = maxf(min_x, zr)
		else: max_x = minf(max_x, zl)
		if pos.x - Enemy.SIZE.x / 2.0 < min_x or pos.x + Enemy.SIZE.x / 2.0 > max_x:
			return {}  # marker itself is inside a safe zone
	return {"kind": kind, "pos": pos, "min_x": min_x, "max_x": max_x}

func _spawn_enemies() -> void:
	for s in specs:
		var e: Enemy = Flyer.new() if s.kind == "flyer" else Enemy.new()
		if s.kind == "walker":
			e.look = "walker"
		e.position = s.pos
		e.patrol_min_x = s.min_x
		e.patrol_max_x = s.max_x
		level.add_child(e)

## On death or R: every enemy (stomped ones too) goes back to its marker.
func _reset() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_spawn_enemies()
