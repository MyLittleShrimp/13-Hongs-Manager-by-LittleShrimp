extends Node2D
## Short presentation timeline. The controller commits one action after completion.
signal completed
var active := false
var paused := false
var kind := ""
var step := 0
var elapsed := 0.0
var duration := 1.4

func begin(action_kind: String, action_step: int) -> void:
	kind = action_kind
	step = action_step
	elapsed = 0
	duration = {"inspection_work":[1.25, 1.35, 1.5], "roasting_work":[1.3, 1.65, 1.8], "packing_work":[1.5, 1.8, 2.0], "loading_work":[1.8, 1.7, 1.9]}[kind][step]
	active = true
	paused = false
	queue_redraw()

func cancel() -> void:
	active = false
	paused = false
	queue_redraw()

func progress() -> float:
	return clampf(elapsed / duration, 0, 1)

func caption() -> String:
	if kind == "packing_work": return ["铺衬压角", "装茶摊平", "压盖扎绳"][step]
	if kind == "loading_work": return ["点四箱上船", "接着搬三箱", "清点最后三箱"][step]
	return ["摊叶看形", "捻叶辨湿", "端详汤色"][step] if kind == "inspection_work" else ["拨匀炭火", "翻茶散湿", "收茶回凉"][step]

func dialogue() -> String:
	if kind == "packing_work": return ["衬料展开，四角压住。茶货放进去前，先护好箱里。", "茶货倒进来，摊平些，给合盖留好位置。", "压住箱盖，绳子收紧。封好这一箱，其余茶箱照样料理。"][step]
	if kind == "loading_work": return ["第一批四箱。你点清，我来接应，轻放在船上。", "再来三箱，接着码好。点过的与岸上的分清，别重复算。", "最后三箱，合起来十箱。把岸上的余货再看一遍。"][step]
	if kind == "inspection_work":
		return ["把茶样摊开，看看叶形齐不齐。", "轻捻茶叶，辨辨干爽还是潮软。", "看看茶汤，留意清浊。"][step]
	return ["拨匀炭火，让茶叶受热均匀。", "翻开，再摊匀，让热气散出去。", "摊开回凉，收好后再看货色。"][step]

func tool_position() -> Vector2:
	var p := progress()
	match step:
		0: return Vector2(1030 - sin(p * PI) * 130, 628 + sin(p * TAU * 2) * 13)
		1: return Vector2(940 + sin(p * TAU * 1.5) * 136, 520 - absf(sin(p * TAU * 1.5)) * 24)
	return Vector2(930, 536).lerp(Vector2(1190, 610), smoothstep(0, 0.62, p)) + Vector2(sin(p * TAU * 3) * 7, -sin(p * PI) * 18)

func tool_rotation() -> float:
	return sin(progress() * TAU * (2 if step == 0 else 1.5)) * 0.24 if step < 2 else sin(progress() * TAU * 3) * 0.065

func _process(delta: float) -> void:
	if not active or paused: return
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		active = false
		completed.emit()

func _leaf(at: Vector2, angle: float, size: float = 1.0) -> void:
	draw_set_transform(at, angle, Vector2.ONE * size)
	draw_colored_polygon(PackedVector2Array([Vector2(-15, 0), Vector2(-6, -4), Vector2(8, -3), Vector2(16, 0), Vector2(3, 4), Vector2(-9, 3)]), Color("555035"))
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color("a19358"), 1, true)
	draw_set_transform(Vector2.ZERO)

func _steam(origin: Vector2, strength: float) -> void:
	for i in 9:
		var p := fmod(progress() * 1.7 + i * 0.113, 1.0)
		var at := origin + Vector2(sin(i * 5.1 + p * 4) * 30, -p * 100)
		draw_arc(at, 8 + p * 19, 0.3, 2.8, 20, Color(0.94, 0.88, 0.73, (1 - p) * strength), 3, true)

func _draw() -> void:
	if not active: return
	if kind in ["packing_work", "loading_work"]: return
	var p := progress()
	if kind == "inspection_work":
		var center := Vector2(680 + step * 310, 545)
		var lift := sin(p * PI)
		draw_set_transform(center, 0, Vector2(1, 0.43))
		draw_circle(Vector2.ZERO, 87 + lift * 9, Color(0.93, 0.81, 0.56, 0.12))
		draw_arc(Vector2.ZERO, 88, 0, TAU, 80, Color(0.93, 0.81, 0.56, 0.65), 2, true)
		draw_set_transform(Vector2.ZERO)
		if step == 0:
			for i in 13:
				var at := center + Vector2((i % 5 - 2) * (15 + lift * 15), floori(i / 5.0) * 16 - 25 - lift * 60)
				_leaf(at, sin(i * 4.3) * 0.9 + lift * 0.2, 1.0 + lift * 0.15)
		elif step == 1:
			for i in 3:
				_leaf(center + Vector2((i - 1) * 31, -lift * 65), sin(p * TAU * 2 + i) * 0.4, 1.7)
		else:
			draw_set_transform(center + Vector2(0, -17), 0, Vector2(1, 0.36))
			for i in 3: draw_arc(Vector2.ZERO, 20 + fmod(p * 44 + i * 14, 42), 0, TAU, 60, Color(0.95, 0.76, 0.4, 0.55 * (1 - p * 0.5)), 2, true)
			draw_set_transform(Vector2.ZERO)
			_steam(center + Vector2(0, -24), 0.24)
	elif step == 0:
		for i in 18:
			var t := fmod(p * 2 + i * 0.06, 1.0)
			var at := Vector2(850 + i * 11, 651 - t * 55)
			draw_circle(at, 2 + (1 - t) * 2, Color(1, 0.52 + i % 3 * 0.08, 0.15, (1 - t) * 0.8))
	else:
		var center := Vector2(945, 535) if step == 1 else tool_position()
		for i in 32:
			var spread := 82.0 if step == 1 else 47.0
			var at := center + Vector2(sin(i * 13.1) * spread, cos(i * 7.3) * 25)
			if step == 1: at.y -= absf(sin(p * TAU * 1.5 + i * 0.2)) * 57
			_leaf(at, i * 2.1 + (p * TAU if step == 1 else sin(p * TAU) * 0.15), 0.6)
		_steam(center - Vector2(0, 20), 0.28 if step == 1 else 0.25 * (1 - p))
