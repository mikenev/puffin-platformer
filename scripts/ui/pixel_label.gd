@tool
class_name PixelLabel
extends Control
## Control that renders text with PixelFont.

@export var text := "": set = set_text
@export var color := Color.WHITE: set = set_color
@export var shadow := Color(0.08, 0.1, 0.2, 1.0)
@export_range(1, 4) var pixel_scale := 1: set = set_pixel_scale
@export var centered := false

func set_text(v: String) -> void:
	text = v
	_resize()

func set_color(v: Color) -> void:
	color = v
	queue_redraw()

func set_pixel_scale(v: int) -> void:
	pixel_scale = v
	_resize()

func _resize() -> void:
	custom_minimum_size = Vector2(PixelFont.text_width(text, pixel_scale) + pixel_scale, (PixelFont.H + 1) * pixel_scale)
	queue_redraw()

func _draw() -> void:
	var x := 0.0
	if centered:
		x = floorf((size.x - PixelFont.text_width(text, pixel_scale)) / 2.0)
	PixelFont.draw_text(self, text, Vector2(x, 0), color, pixel_scale, shadow)
