extends Node2D
## Tea and paper move into the open chest; decorative motion uses its own fixed layout.
var step := 0
var age := 0.0
var sealed := false

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	if sealed:
		var progress := minf(age * 1.4, 1)
		var rope_color := Color(0.82, 0.69, 0.48, clampf(1 - age * 1.1, 0, 1))
		var points := [Vector2(-144,-5), Vector2(8,-58), Vector2(129,-2), Vector2(139,111)]
		for i in 3:
			var local_progress := clampf(progress * 3 - i, 0, 1)
			draw_line(points[i], points[i].lerp(points[i + 1], local_progress), rope_color, 5, true)
		draw_line(Vector2(-21,46), Vector2(-21,46).lerp(Vector2(-16,143), progress), rope_color, 5, true)
	elif step == 1:
		var p := minf(age * 2.2, 1.0)
		var center := Vector2(0, lerpf(-190, -10, p))
		var points := PackedVector2Array([center + Vector2(-78,-28), center + Vector2(30,-52), center + Vector2(90,4), center + Vector2(-21,23)])
		draw_colored_polygon(points, Color(0.90, 0.84, 0.68, 1 - p * 0.6))
	elif step >= 2:
		for i in 54:
			var delay := (i % 9) * 0.05
			var progress := clampf((age - delay) * 2.0, 0, 1)
			var target := Vector2(sin(i * 7.1) * 97, sin(i * 4.2) * 22)
			var pos := target + Vector2(40 * (1 - progress), -150 * (1 - progress))
			draw_set_transform(pos, i * 0.4, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 5 + i % 4, Color("455132") if i % 2 == 0 else Color("665b34"))
		draw_set_transform(Vector2.ZERO)
