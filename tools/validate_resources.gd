extends SceneTree
## Validates the M2 art resources. Exits 1 on any failure.
## Run: godot --headless -s tools/validate_resources.gd

const EXPECTED := {
	"idle": [6, true], "run": [4, true], "skid": [2, true],
	"jump": [2, false], "fall": [2, true], "death": [6, false],
}
const SOLID := 18
const ONE_WAY := 4
var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		printerr("FAIL ", msg)
		failures += 1

func _init() -> void:
	var sf := load("res://art/puffin/puffin_frames.tres") as SpriteFrames
	check(sf != null, "puffin_frames.tres loads as SpriteFrames")
	if sf:
		var names := sf.get_animation_names()
		check(names.size() == EXPECTED.size(), "animation count == %d (got %d)" % [EXPECTED.size(), names.size()])
		for a: String in EXPECTED:
			check(sf.has_animation(a), "has animation '%s'" % a)
			if not sf.has_animation(a):
				continue
			check(sf.get_frame_count(a) == EXPECTED[a][0], "%s frames == %d (got %d)" % [a, EXPECTED[a][0], sf.get_frame_count(a)])
			check(sf.get_animation_loop(a) == EXPECTED[a][1], "%s loop == %s" % [a, EXPECTED[a][1]])
			check(sf.get_animation_speed(a) > 0.0, "%s fps > 0" % a)
			for i in sf.get_frame_count(a):
				var t := sf.get_frame_texture(a, i)
				check(t != null and t.get_size() == Vector2(16, 16), "%s[%d] is a 16x16 texture" % [a, i])
	var raw := FileAccess.get_file_as_string("res://art/puffin/puffin_frames.tres")
	check(not raw.contains("\"loop\": 0") and not raw.contains("\"loop\": 1"), "loop flags stored as booleans")

	var ts := load("res://art/tiles/coastal_tileset.tres") as TileSet
	check(ts != null, "coastal_tileset.tres loads as TileSet")
	if ts:
		check(ts.tile_size == Vector2i(16, 16), "tile_size == 16x16")
		check(ts.get_physics_layers_count() == 1, "one physics layer")
		check(ts.get_source_count() == 1 and ts.has_source(0), "single atlas source id 0")
		var src := ts.get_source(0) as TileSetAtlasSource
		check(src != null and src.texture != null, "atlas source has a texture")
		if src and src.texture:
			check(src.texture.get_size() == Vector2(128, 64), "atlas texture is 128x64")
			check(src.texture_region_size == Vector2i(16, 16), "atlas region size 16x16")
			check(src.get_tiles_count() == 32, "32 tiles (got %d)" % src.get_tiles_count())
			var solid := 0
			var oneway := 0
			for i in src.get_tiles_count():
				var td := src.get_tile_data(src.get_tile_id(i), 0)
				if td.get_collision_polygons_count(0) == 0:
					continue
				var pts := td.get_collision_polygon_points(0, 0)
				check(pts.size() >= 3, "tile %s polygon has >= 3 points" % src.get_tile_id(i))
				if td.is_collision_polygon_one_way(0, 0):
					oneway += 1
				else:
					solid += 1
			check(solid == SOLID, "solid collision tiles == %d (got %d)" % [SOLID, solid])
			check(oneway == ONE_WAY, "one-way platform tiles == %d (got %d)" % [ONE_WAY, oneway])
			for c in [Vector2i(5, 2), Vector2i(6, 2), Vector2i(0, 3)]:  # water, water, decor
				check(src.get_tile_data(c, 0).get_collision_polygons_count(0) == 0, "tile %s has no collision" % c)
	if failures > 0:
		printerr("VALIDATION FAILED: %d check(s)" % failures)
		quit(1)
	else:
		print("VALIDATION OK")
		quit(0)
