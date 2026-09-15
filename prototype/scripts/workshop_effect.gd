extends Node2D
## Procedural motion over the painted scenery. No access to economy RNG.
var stage := ""
var step := 0
var age := 0.0
var pulse := 0.0
var target := Vector2.ZERO
var wet := false
var damaged := false
var cargo_count := 10
var marked: Array = []
var token := ""

func configure(model) -> void:
	var next := "%s:%d:%d:%d" % [model.stage, model.roast_step, model.packing_step, model.inspection_marks.size()]
	if token != next:
		age = 0
		token = next
	stage = model.stage
	step = model.roast_step if stage == "roasting_work" else model.packing_step
	marked = model.inspection_marks.duplicate()
	wet = model.cargo_event in ["leak", "squall"]
	damaged = not model.pending_delivery.is_empty() and bool(model.pending_delivery.damaged)
	cargo_count = int(model.pending_delivery.delivered) if not model.pending_delivery.is_empty() else 10

func play_at(point: Vector2) -> void:
	pulse = 1
	target = point

func _process(delta: float) -> void:
	age += delta
	pulse = maxf(0, pulse - delta * 1.3)
	queue_redraw()

func _draw() -> void:
	if stage in ["roast_plan", "roasting_work"]:
		# Embers and steam stay anchored to the painted roasting basket.
		for i in 22:
			var p := fmod(age * 0.26 + i * 0.047, 1.0)
			var pos := Vector2(790 + i * 16 + sin(age + i) * 18, 607 - p * 222)
			draw_circle(pos, 5 + p * 13, Color(0.94, 0.88, 0.70, (1 - p) * 0.11))
		for i in 11:
			var pos := Vector2(895 + i * 13, 712 + sin(i * 7.0) * 10)
			draw_circle(pos, 3 + sin(age * 5 + i), Color(1, 0.37, 0.07, 0.55))
		if stage == "roasting_work" and step > 0:
			for i in 28:
				var pos := Vector2(875 + i % 8 * 22, 575 + sin(i * 8.1) * 25 - abs(sin(age * 2.7 + i * 0.2)) * 15)
				draw_line(pos, pos + Vector2(9, 4), Color("65603c"), 4, true)
	if stage == "inspection_work":
		for i in 3:
			var pos := Vector2(680 + i * 310, 545)
			var color := Color(0.85, 0.72, 0.47, 0.45 + sin(age * 2) * 0.12)
			if i in marked: color = Color(0.65, 0.83, 0.65, 0.8)
			draw_arc(pos, 75, 0, TAU, 70, color, 2.5, true)
	if stage in ["voyage", "voyage_report"] and wet:
		var water := 0.14 if stage == "voyage" else (0.25 if damaged else 0.06)
		for i in 8:
			var pos := Vector2(660 + i * 94, 745 + sin(age * 1.7 + i) * 6 + i % 3 * 18)
			draw_set_transform(pos, 0, Vector2(1, 0.15))
			draw_circle(Vector2.ZERO, 96, Color(0.20, 0.37, 0.36, water))
			draw_set_transform(Vector2.ZERO)
	if stage in ["voyage", "voyage_report"]:
		for i in 10:
			var pos := Vector2(785 + (i % 5) * 93, 659 + floori(float(i) / 5) * 87)
			draw_set_transform(pos, 0, Vector2(1, 0.13))
			draw_circle(Vector2.ZERO, 43, Color(0.10, 0.08, 0.04, 0.13))
			draw_set_transform(Vector2.ZERO)
	if pulse > 0:
		draw_arc(target, 35 + (1 - pulse) * 65, 0, TAU, 48, Color(0.98, 0.84, 0.52, pulse), 4, true)
