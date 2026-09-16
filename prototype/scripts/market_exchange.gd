extends Node2D
## A paper receipt passes across the counter; amounts are fictional game money.
var age := 0.0
var active := false
var receiving := false
var font: Font
var paid := 0

func play_exchange(amount: int, take_receipt: bool = false) -> void:
	paid = amount
	receiving = take_receipt
	age = 0
	active = true
	visible = true

func _process(delta: float) -> void:
	if not active: return
	age += delta
	queue_redraw()
	if age >= 1.25:
		active = false
		visible = false

func _draw() -> void:
	if not active: return
	var p := smoothstep(0, 1, minf(age / 1.0, 1))
	if receiving:
		var paper := Vector2(1120, 664).lerp(Vector2(650, 696), p)
		draw_set_transform(paper, -0.07 + p * 0.13)
		draw_style_box(_paper_style(), Rect2(-71, -48, 142, 96))
		if font:
			draw_string(font, Vector2(-48, -9), "茶货单", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("22392e"))
			draw_string(font, Vector2(-48, 24), "实付%d" % paid, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("22392e"))
	else:
		for i in 5:
			var t := smoothstep(0, 1, clampf((age - i * 0.075) / 0.7, 0, 1))
			var at := Vector2(650 + i * 8, 691).lerp(Vector2(1180 + i * 13, 704), t)
			at.y -= sin(t * PI) * 38
			draw_circle(at, 11, Color("c5a268"))
			draw_arc(at, 7, 0, TAU, 24, Color("f4df9a"), 2, true)
		if font: draw_string(font, Vector2(840, 728), "付清 %d" % paid, HORIZONTAL_ALIGNMENT_CENTER, 240, 26, Color("f4eddd"))
	draw_set_transform(Vector2.ZERO)

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4eddd")
	style.border_color = Color("b39660")
	style.set_border_width_all(2)
	return style
