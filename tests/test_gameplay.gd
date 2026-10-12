extends SceneTree
## Scripted gameplay checks for enemies, stomp, fish power-ups, dive, glide and audio calls.
## Run: godot --headless --fixed-fps 60 -s res://tests/test_gameplay.gd
var L: Node
var P: Puffin
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func press(a: String, on := true) -> void:
	if on: Input.action_press(a)
	else: Input.action_release(a)

func reset_at(pos: Vector2, pw := Puffin.Power.NONE) -> void:
	for a in ["move_left", "move_right", "jump", "run", "move_down"]: press(a, false)
	P.respawn(false)
	P.global_position = pos
	P.velocity = Vector2.ZERO
	P.set_power(pw)
	await frames(2)

func enemy_at(x: float) -> Enemy:
	var e := Enemy.new()
	e.speed = 0.0
	e.position = Vector2(x, 192 - Enemy.SIZE.y / 2.0)
	L.add_child(e)
	return e

func _run() -> void:
	L = load("res://scenes/main.tscn").instantiate()
	root.add_child(L)
	await frames(3)
	P = L.get_node("Puffin")
	ok(Sfx.history.has("music:world1_theme"), "level start plays music world1_theme")
	for n in ["jump", "land", "skid", "death", "collect_fish", "powerup", "stomp"]:
		ok(ResourceLoader.exists("res://audio/sfx/%s.ogg" % n), "sfx asset exists: " + n)
	var enemies := L.get_children().filter(func(c): return c is Enemy)
	var fish := L.get_children().filter(func(c): return c is FishPickup)
	ok(enemies.size() >= 3, "level has %d enemies" % enemies.size())
	ok(enemies.all(func(e): return absf(e.position.x - P.spawn_point.x) > 128), "no enemy within 8 tiles of spawn")
	ok(fish.size() >= 4, "level has %d fish" % fish.size())
	# keep level enemies away from test area (x 300-400 on ground c0-25)
	for e in enemies: if e.position.x < 450: e.queue_free()
	for f in fish: if f.position.x < 450: f.queue_free()
	await frames(2)

	# Patrol turns at a wall: start one walking toward the r11 step side? use ledge at gap1 (x 416)
	var w := Enemy.new(); w.position = Vector2(400, 187); w.dir = 1; L.add_child(w)
	await frames(90)
	ok(w.dir == -1 and w.global_position.x < 416 and w.global_position.y < 200, "enemy turns at ledge (dir %d x %.0f)" % [w.dir, w.global_position.x])
	w.queue_free()

	# Stomp (normal and with jump held)
	var bounce := []
	for held in [false, true]:
		Sfx.history.clear()
		var e := enemy_at(380)
		await frames(2)
		await reset_at(Vector2(380, 120))
		var vy_after := 0.0
		for i in 90:
			if held and i == 10: press("jump")  # after coyote time, so it is not a jump
			await physics_frame
			if not is_instance_valid(e) or e.squashed:
				vy_after = P.velocity.y
				break
		ok(not is_instance_valid(e) or e.squashed, "stomp squashes enemy (held=%s)" % held)
		ok(vy_after < 0.0, "puffin bounces off stomp (vy %.0f)" % vy_after)
		ok(not P.is_dying(), "stomp does not kill puffin")
		ok(Sfx.history.has("stomp"), "stomp sfx fired")
		bounce.append(vy_after)
		press("jump", false)
		await frames(30)
		ok(not is_instance_valid(e), "squashed enemy removed")
	ok(bounce[1] < bounce[0] - 50, "held-jump bounce higher (vy %.0f vs %.0f)" % [bounce[1], bounce[0]])

	# Side hit while normal -> death
	Sfx.history.clear()
	var e2 := enemy_at(380)
	await reset_at(Vector2(350, 183))
	press("move_right")
	await frames(40)
	ok(P.is_dying(), "side hit kills unpowered puffin")
	ok(Sfx.history.has("death"), "death sfx fired")
	ok(not e2.squashed, "side hit does not stomp")
	e2.queue_free()

	# Side hit while powered -> depower + invuln, no death
	var e3 := enemy_at(380)
	await reset_at(Vector2(350, 183), Puffin.Power.GLIDE)
	press("move_right")
	await frames(40)
	ok(not P.is_dying() and P.power == Puffin.Power.NONE and P.is_invulnerable(), "powered side hit drops power, survives, invulnerable")
	e3.queue_free()

	# Fish grant powers
	for pw in [Puffin.Power.DIVE, Puffin.Power.GLIDE]:
		Sfx.history.clear()
		await reset_at(Vector2(200, 183))
		var f := FishPickup.new(); f.power = pw; f.position = Vector2(230, 180); L.add_child(f)
		press("move_right")
		await frames(40)
		press("move_right", false)
		ok(P.power == pw, "fish grants power %s" % Puffin.Power.keys()[pw])
		ok(Sfx.history.has("collect_fish") and Sfx.history.has("powerup"), "collect + powerup sfx fired")
		ok(P.sprite.modulate != Color.WHITE, "puffin tinted for power")

	# Dive
	await reset_at(Vector2(200, 60), Puffin.Power.DIVE)
	await frames(5)
	press("move_down"); await frames(1); press("move_down", false)
	await frames(2)
	ok(P.diving and P.velocity.y >= P.dive_speed - 1, "dive: fast downward (vy %.0f)" % P.velocity.y)
	var e4 := enemy_at(200)
	await frames(40)
	ok(is_instance_valid(e4) == false or e4.squashed, "dive stomps enemy on impact")

	# Glide vs normal fall
	var vys := []
	for pw in [Puffin.Power.NONE, Puffin.Power.GLIDE]:
		await reset_at(Vector2(200, -60), pw)
		press("jump")
		await frames(40)
		vys.append(P.velocity.y)
		press("jump", false)
	ok(vys[1] <= P.glide_fall_speed + 0.5 and vys[0] > 200, "glide caps fall speed (%.0f vs normal %.0f)" % [vys[1], vys[0]])

	# Jump/land sfx
	Sfx.history.clear()
	await reset_at(Vector2(200, 183))
	await frames(5)
	press("jump"); await frames(30); press("jump", false); await frames(60)
	ok(Sfx.history.has("jump") and Sfx.history.has("land"), "jump + land sfx fired")
	# Skid sfx
	Sfx.history.clear()
	await reset_at(Vector2(100, 183))
	press("move_right"); press("run"); await frames(50); press("move_right", false); press("move_left"); await frames(10)
	ok(Sfx.history.has("skid"), "skid sfx fired")
	press("move_left", false); press("run", false)
	print("RESULT: %d failures" % fails)
	quit(1 if fails else 0)
