extends Node2D
## Native ambient motion layered over ImageGen scenery. Visual RNG never touches the economy.
var place := "counter"
var wet := false
var storm := false
var age := 0.0
var rain: Array[Vector2] = []
var visual_rng := RandomNumberGenerator.new()

func exposed(point: Vector2) -> bool:
	# Weather is behind the actors. Indoors, rain only crosses visible openings.
	match place:
		"counter": return Rect2(435, 140, 815, 540).has_point(point)
		"inspection": return Rect2(385, 100, 245, 304).has_point(point) or Rect2(1520, 75, 220, 330).has_point(point)
		"roasting": return Rect2(32, 85, 455, 375).has_point(point)
		"packing": return Rect2(610, 245, 870, 198).has_point(point)
		"vessel": return point.y < 490 and point.y > 90
		"market": return Rect2(405, 90, 697, 610).has_point(point)
		"dock": return point.x > 360 and point.y < 815
	return false

func _ready() -> void:
	visual_rng.seed = 8137
	for i in 90:
		rain.append(Vector2(visual_rng.randf_range(0, 1920), visual_rng.randf_range(70, 820)))

func _process(delta: float) -> void:
	age += delta
	if wet:
		for i in rain.size():
			rain[i] += Vector2(-130 if storm else -45, 650) * delta
			if rain[i].y > 805:
				rain[i] = Vector2(visual_rng.randf_range(0, 2080), 82)
	queue_redraw()

func _draw() -> void:
	if place in ["dock", "vessel"]:
		for i in 22:
			var x := fmod(i * 91.0 + age * 14, 1500) + 210
			var y := 440 + (i % 6) * 20 + sin(age + i) * 3
			draw_line(Vector2(x, y), Vector2(x + 30 + i % 35, y), Color(0.96, 0.85, 0.62, 0.13), 2)
	if wet:
		for point in rain:
			var end := point + Vector2(-5 if storm else -2, 25)
			if exposed(point) and exposed(end):
				draw_line(point, end, Color(0.85, 0.91, 0.92, 0.30), 1.3)
	if not wet and place in ["packing", "counter", "market", "inspection", "roasting"]:
		for i in 28:
			var x := fmod(i * 73.0 + age * 5, 1920)
			var y := 150 + fmod(i * 39 + sin(age * 0.4 + i) * 25, 560)
			draw_circle(Vector2(x, y), 1.7, Color(1, 0.84, 0.48, 0.20))
