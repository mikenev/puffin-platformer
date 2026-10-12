extends SceneTree
func _init() -> void:
	var sf: SpriteFrames = load("res://art/puffin/puffin_frames.tres")
	for a in sf.get_animation_names():
		print(a, " frames=", sf.get_frame_count(a), " fps=", sf.get_animation_speed(a), " loop=", sf.get_animation_loop(a))
	var ts: TileSet = load("res://art/tiles/coastal_tileset.tres")
	var src: TileSetAtlasSource = ts.get_source(0)
	var n := 0
	for i in src.get_tiles_count():
		if src.get_tile_data(src.get_tile_id(i), 0).get_collision_polygons_count(0) > 0: n += 1
	print("tiles=", src.get_tiles_count(), " with collision=", n, " tile_size=", ts.tile_size)
	quit()
