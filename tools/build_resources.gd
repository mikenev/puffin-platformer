extends SceneTree
## Builds art/puffin/puffin_frames.tres and art/tiles/coastal_tileset.tres from the generated PNGs.
## Run: godot --headless --import && godot --headless -s tools/build_resources.gd

func _init() -> void:
	var sheet: Texture2D = load("res://art/puffin/puffin_sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var row := 0
	for line in FileAccess.get_file_as_string("res://art/puffin/anims.txt").strip_edges().split("\n"):
		var p := line.split(" ")
		var anim := StringName(p[0])
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(p[2]))
		sf.set_animation_loop(anim, p[3] == "1")
		for i in int(p[1]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * 16, row * 16, 16, 16)
			sf.add_frame(anim, at)
		row += 1
	var path := "res://art/puffin/puffin_frames.tres"
	print("SpriteFrames save: ", ResourceSaver.save(sf, path))
	# Godot writes loop as 0/1 inside the animation dictionaries; store real booleans instead.
	var txt := FileAccess.get_file_as_string(path).replace("\"loop\": 0,", "\"loop\": false,").replace("\"loop\": 1,", "\"loop\": true,")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()

	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles/coastal_tiles.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var plank := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)])
	for line in FileAccess.get_file_as_string("res://art/tiles/tiles.txt").strip_edges().split("\n"):
		var p := line.split(" ")
		var c := Vector2i(int(p[0]), int(p[1]))
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		if p[3] == "solid" or p[3] == "oneway":
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full if p[3] == "solid" else plank)
			td.set_collision_polygon_one_way(0, 0, p[3] == "oneway")
	print("TileSet save: ", ResourceSaver.save(ts, "res://art/tiles/coastal_tileset.tres"))
	quit()
