extends Control
var progress := 0.0
var click_age := 10.0
var point := Vector2.ZERO
var cinematic := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not cinematic:
		draw_rect(Rect2(167,164,1586,893),Color(0.78,0.67,0.45,0.38),false,1.0)
	if click_age < 0.65:
		var alpha := 1 - click_age / 0.65
		draw_arc(point,17 + click_age * 45,0,TAU,60,Color(1,0.87,0.58,alpha),3,true)
		draw_circle(point,5,Color(1,0.89,0.64,alpha))
	draw_rect(Rect2(0,1076,1920 * progress,4),Color("d9b879"))
