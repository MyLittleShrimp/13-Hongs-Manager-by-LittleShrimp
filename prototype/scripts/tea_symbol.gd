extends Control
## Small native UI ornament, not a substitute for historical object photography.
var ink := Color("264f42")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 100.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var left := PackedVector2Array([Vector2(48, 71), Vector2(21, 63), Vector2(11, 31), Vector2(39, 37), Vector2(48, 71)])
	var right := PackedVector2Array([Vector2(49, 58), Vector2(58, 24), Vector2(88, 12), Vector2(83, 44), Vector2(49, 58)])
	draw_colored_polygon(left, Color(ink, 0.13))
	draw_colored_polygon(right, Color(ink, 0.13))
	draw_polyline(left, ink, 2.0, true)
	draw_polyline(right, ink, 2.0, true)
	draw_line(Vector2(48, 87), Vector2(53, 50), ink, 2.0, true)
	draw_line(Vector2(47, 69), Vector2(24, 44), ink, 1.5, true)
	draw_line(Vector2(51, 56), Vector2(76, 26), ink, 1.5, true)
