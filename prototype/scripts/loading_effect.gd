extends Node2D
## Ten existing crates move in counted groups, without economic RNG or fees.
var texture: Texture2D
var font: Font
var loaded := 0
var batch := 4
var performing := false
var progress := 0.0

func _ready() -> void:
	texture = load("res://assets/props/tea_crate.png")

func _process(_delta: float) -> void:
	queue_redraw()

func dock_position(i: int) -> Vector2:
	return Vector2(645 + i % 4 * 78, 641 + floori(i / 4.0) * 39)

func boat_position(i: int) -> Vector2:
	return Vector2(1300 + i % 4 * 73, 580 + floori(i / 4.0) * 32)

func position_for(i: int) -> Vector2:
	if i < loaded: return boat_position(i)
	if performing and i < loaded + batch:
		var p := clampf((progress - (i - loaded) * 0.12) / 0.62, 0, 1)
		return dock_position(i).lerp(boat_position(i), smoothstep(0,1,p)) + Vector2(0, -sin(p * PI) * 92)
	return dock_position(i)

func _draw() -> void:
	if texture == null: return
	for i in 10:
		var at := position_for(i)
		var scale_amount := 1.0 if i < loaded else (clampf((progress - (i-loaded) * 0.12) / 0.62, 0, 1) if performing and i < loaded + batch else 0.0)
		var dimensions := Vector2(105,70).lerp(Vector2(87,58), scale_amount)
		draw_set_transform(at + dimensions * Vector2(0.5,0.91), 0, Vector2(1,0.18))
		draw_circle(Vector2.ZERO, dimensions.x * 0.42, Color(0.08,0.06,0.03,0.2))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(texture, Rect2(at,dimensions), false)
		if font and i >= loaded:
			var marker := at + dimensions * Vector2(0.35,0.59)
			draw_circle(marker, 10, Color("e3c992"))
			draw_string(font, marker + Vector2(-9,5), str(i+1), HORIZONTAL_ALIGNMENT_CENTER, 18, 13, Color("293c2e"))
