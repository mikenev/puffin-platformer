class_name LevelReach
extends RefCounted
## Static reachability checker for ASCII course maps. Simulates puffin jump arcs tile-by-tile
## with the real Puffin tuning (PR #1) minus a safety margin, BFS from the spawn.

const TILE := 16
const DT := 1.0 / 60.0
const MARGIN := 0.92          ## fraction of real jump speed / run speed the checker may use
const HALF := Vector2(5, 6.5)
const BOX_OFF := Vector2(0, 1.5)
const RUNWAY_TILES := 3       ## tiles of flat ground needed to count as reaching run speed

var map: Array
var w := 0
var h := 0
var p: Puffin
var touched := {}             ## tiles the box passed through on any successful-or-not arc

func _init(m: Array) -> void:
	map = m
	h = m.size()
	w = m[0].length()
	p = Puffin.new()

func free_puffin() -> void:
	p.free()

func c(x: int, y: int) -> String:
	if x < 0 or x >= w:
		return "#"
	if y < 0 or y >= h:
		return "."
	return map[y][x]

func solid(x: int, y: int) -> bool:
	return "#S".contains(c(x, y))

func standable(x: int, y: int) -> bool:
	return (solid(x, y) or c(x, y) == "=") and not solid(x, y - 1) and y >= 1

func find(ch: String) -> Vector2i:
	for y in h:
		var i: int = map[y].find(ch)
		if i >= 0:
			return Vector2i(i, y)
	return Vector2i(-1, -1)

func _box_hits_solid(pos: Vector2) -> bool:
	var a := pos + BOX_OFF - HALF
	var b := pos + BOX_OFF + HALF - Vector2(0.01, 0.01)
	for ty in range(floori(a.y / TILE), floori(b.y / TILE) + 1):
		for tx in range(floori(a.x / TILE), floori(b.x / TILE) + 1):
			if solid(tx, ty):
				return true
	return false

func _touch(pos: Vector2) -> void:
	var a := pos + BOX_OFF - HALF
	var b := pos + BOX_OFF + HALF
	for ty in range(floori(a.y / TILE), floori(b.y / TILE) + 1):
		for tx in range(floori(a.x / TILE), floori(b.x / TILE) + 1):
			touched[Vector2i(tx, ty)] = true

## Returns landing node or (-1,-1).
func _arc(start: Vector2, vx: float, v0: float, hold_frames: int) -> Vector2i:
	var pos := start
	var vy := v0
	var frames := 0
	while frames < 240:
		frames += 1
		var holding := frames <= hold_frames
		var g := p.gravity_rise if (vy < 0.0 and holding) else p.gravity_fall
		if vy < 0.0 and not holding and frames == hold_frames + 1:
			vy *= p.jump_cut_multiplier
		vy = minf(vy + g * DT, p.max_fall_speed)
		var nx := pos + Vector2(vx * DT, 0)
		if _box_hits_solid(nx):
			vx = 0.0
		else:
			pos = nx
		var ny := pos + Vector2(0, vy * DT)
		var feet_before := pos.y + BOX_OFF.y + HALF.y
		var feet_after := ny.y + BOX_OFF.y + HALF.y
		if vy > 0.0:
			# Land on solid or one-way tiles whose top we crossed this frame.
			var x0 := floori((ny.x - HALF.x) / TILE)
			var x1 := floori((ny.x + HALF.x - 0.01) / TILE)
			var ty := floori(feet_after / TILE)
			var top := ty * TILE
			if feet_before <= top + 0.01 and feet_after >= top:
				var best := Vector2i(-1, -1)
				for tx in range(x0, x1 + 1):
					if standable(tx, ty):
						if best.x < 0 or absi(tx - floori(ny.x / TILE)) < absi(best.x - floori(ny.x / TILE)):
							best = Vector2i(tx, ty)
				if best.x >= 0:
					return best
			if _box_hits_solid(ny):
				return Vector2i(-1, -1)  # wedged; treat as fail
		elif _box_hits_solid(ny):
			vy = 0.0
			continue
		pos = ny
		_touch(pos)
		if pos.y > h * TILE:
			return Vector2i(-1, -1)
	return Vector2i(-1, -1)

func _runway(x: int, y: int, dir: int) -> int:
	var n := 0
	var cx := x - dir
	while standable(cx, y) and n < RUNWAY_TILES:
		n += 1
		cx -= dir
	return n

func reachable() -> Dictionary:
	var spawn := find("P")
	var start := Vector2i(spawn.x, spawn.y + 1)
	while not standable(start.x, start.y) and start.y < h:
		start.y += 1
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var jv := p.jump_velocity * MARGIN
	while not queue.is_empty():
		var n: Vector2i = queue.pop_front()
		var out: Array[Vector2i] = []
		for d in [-1, 1]:
			if standable(n.x + d, n.y) and not solid(n.x + d, n.y - 1):
				out.append(Vector2i(n.x + d, n.y))
		var feet_y := n.y * TILE - BOX_OFF.y - HALF.y
		for d in [-1, 1]:
			var speeds := [0.0, p.walk_speed * 0.5 * MARGIN, p.walk_speed * MARGIN]
			if _runway(n.x, n.y, d) >= RUNWAY_TILES:
				speeds.append(p.run_speed * MARGIN)
			for vx in speeds:
				var bonus: float = p.run_jump_bonus * MARGIN * clampf(vx / p.run_speed, 0, 1)
				for xo in [0.0, 6.0 * d]:
					var s := Vector2(n.x * TILE + 8 + xo, feet_y)
					for j in [[jv + bonus, 999], [jv + bonus, 10], [0.0, 0]]:
						if j[0] == 0.0 and xo == 0.0:
							continue
						var land := _arc(s, vx * d, j[0], j[1])
						if land.x >= 0:
							out.append(land)
		for o in out:
			if not seen.has(o):
				seen[o] = true
				queue.append(o)
	return seen
