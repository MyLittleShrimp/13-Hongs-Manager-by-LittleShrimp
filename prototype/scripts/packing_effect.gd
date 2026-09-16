extends Node2D
## Layers on the existing chest, driven by the shared pausable timeline.
var step := 0
var sealed := false
var performing := false
var manual_rope := false
var manual_lid_open := false
var manual_fill := false
var manual_liner := false
var progress := 0.0
var protection := 0.0
var age := 0.0
var _draw_state: Array = []
const RIM := [Vector2(-178,18), Vector2(-80,-52), Vector2(176,0), Vector2(88,48)]
const LID := [Vector2(-220,8), Vector2(-83,-81), Vector2(219,-15), Vector2(95,68)]

func _process(_delta: float) -> void:
	# Godot retains CanvasItem commands. Keep the stationary lid/woodgrain cached
	# while the separate gesture layer draws the moving rope; animate on actual changes.
	var state := [step,sealed,performing,manual_rope,manual_lid_open,manual_fill,manual_liner,progress,protection]
	if state != _draw_state:
		_draw_state = state
		queue_redraw()

func _leaf(at: Vector2, index: int) -> void:
	draw_set_transform(at, index * 1.37, Vector2(1, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(-7,0),Vector2(-2,-4),Vector2(8,0),Vector2(1,4)]), Color("4e5432") if index % 2 == 0 else Color("746340"))
	draw_set_transform(Vector2.ZERO)

func _rope(points: Array, amount: float) -> void:
	for i in points.size() - 1:
		var p := clampf(amount * (points.size() - 1) - i, 0, 1)
		if p > 0:
			draw_line(points[i], points[i].lerp(points[i+1], p), Color("765634"), 8, true)
			draw_line(points[i] + Vector2(0,-1), points[i].lerp(points[i+1], p) + Vector2(0,-1), Color("d1b27e"), 4, true)

func _draw() -> void:
	if sealed: return
	var p := progress if performing else 0.0
	if step >= 1 or (performing and step == 0 and (not manual_liner or p > 0)):
		var unfold := smoothstep(0, 0.72, p) if step == 0 else 1.0
		var center := Vector2(0, -(1 - unfold) * 110)
		var paper := PackedVector2Array()
		for point in RIM: paper.append(center + point * Vector2(0.22 + unfold * 0.78, 0.35 + unfold * 0.65))
		draw_colored_polygon(paper, Color("c9b788") if protection < 0.2 else Color("e2d1a8"))
		for i in 6:
			draw_line(paper[0].lerp(paper[1], i / 6.0), paper[3].lerp(paper[2], i / 6.0), Color(0.40,0.31,0.19,0.2), 1, true)
	if step >= 2 or (performing and step == 1):
		var filled := p if manual_fill else (p if step == 1 else 1.0)
		if filled > 0:
			var tea := PackedVector2Array([RIM[0]*0.94,RIM[0].lerp(RIM[1],filled)*0.94,RIM[3].lerp(RIM[2],filled)*0.94,RIM[3]*0.94])
			draw_colored_polygon(tea,Color("4e452d"))
		for i in 110:
			var u := fmod(i * 0.618, 1.0)
			var v := fmod(i * 0.414, 1.0)
			var target: Vector2 = RIM[0].lerp(RIM[1], u).lerp(RIM[3].lerp(RIM[2], u), v) * Vector2(0.94, 0.85)
			var fall := (1.0 if u < p else 0.0) if manual_fill else (clampf((p - (i % 13) * 0.035) * 2.4, 0, 1) if step == 1 else 1.0)
			if fall > 0: _leaf(Vector2(97,-150).lerp(target, fall), i)
	if performing and step == 2 and not manual_lid_open:
		var lower := smoothstep(0.06, 0.5, p)
		var lid := PackedVector2Array()
		for point in LID: lid.append(point + Vector2(0, -115 * (1 - lower)))
		draw_colored_polygon(lid, Color("ac8755"))
		draw_polyline(PackedVector2Array([lid[0],lid[1],lid[2],lid[3],lid[0]]), Color("584329"), 5, true)
		for i in 5:
			draw_line(lid[0].lerp(lid[1], (i+1)/6.0), lid[3].lerp(lid[2], (i+1)/6.0), Color("785733"), 2, true)
		for i in 54:
			var grain := PackedVector2Array()
			var row := (i + 0.5) / 54.0
			for j in 17:
				var ripple := sin(j * 0.9 + i * 1.7) * 0.002
				grain.append(lid[0].lerp(lid[1], row + ripple).lerp(lid[3].lerp(lid[2], row + ripple), j / 16.0))
			draw_polyline(grain, Color(0.31,0.20,0.09,0.12 + (i % 3) * 0.06), 1, true)
		if not manual_rope:
			_rope([Vector2(-160,-29),Vector2(157,27),Vector2(154,146)], smoothstep(0.5,0.85,p))
			_rope([Vector2(14,-61),Vector2(-62,43),Vector2(-65,134)], smoothstep(0.65,1.0,p))
