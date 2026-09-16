extends Control
## A simple currency symbol, not a reproduction of a historical denomination.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	draw_circle(center, radius, Color("c5a268"))
	draw_arc(center, radius * 0.78, 0, TAU, 32, Color("f4df9a"), 1.5, true)
	draw_rect(Rect2(center - Vector2.ONE * radius * 0.22, Vector2.ONE * radius * 0.44), Color("22392e"))
