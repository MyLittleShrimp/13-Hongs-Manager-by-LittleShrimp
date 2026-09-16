extends Node2D
## Pointer-driven work, independent of the economy. Only a valid release completes it.
signal completed
var active := false
var paused := false
var kind := ""
var step := 0
var font: Font
var texture: Texture2D
var cup: Texture2D
var paddle: Texture2D
var captured := false
var pointer_owner := ""
var contact := -1
var last_pointer := Vector2.ZERO
var grab_offset := Vector2.ZERO
var object_position := Vector2.ZERO
var source := Vector2.ZERO
var target := Vector2.ZERO
var cells: Array[Vector2] = []
var loaded := 0
var amount := 0.0
var feedback := ""
var release_ready := false
var settling := 0.0
var swings := 0
var last_edge := 0
var stir_angle := 0.0
var stir_direction := 0.0
var stir_valid := false
var rope_routes: Array[PackedVector2Array] = []
var rope_index := 0
var rope_point := 1
const CUP_CENTER := Vector2(966, 544)
const PAN_CENTER := Vector2(956, 514)
const PAN_RADIUS := Vector2(178, 53)
const CELL := Vector2(94, 59)
const BOX_SIZE := Vector2(122, 82)
const FIT_DISTANCE := 34.0

func _ready() -> void:
	texture = load("res://assets/props/tea_crate.png")
	if ResourceLoader.exists("res://assets/props/tea_cup.png"): cup = load("res://assets/props/tea_cup.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/props/workshop_tools.png")
	var size := atlas.atlas.get_size() / Vector2(3,2)
	atlas.region = Rect2(Vector2(size.x,0), size)
	atlas.filter_clip = true
	paddle = atlas

func begin(mode: String, index: int, seed_value: int = 0, already_loaded: int = 0) -> void:
	cancel()
	kind = mode
	step = index
	loaded = already_loaded
	active = true
	visible = true
	if kind == "loading":
		var shapes: Array = [
			[Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)],
			[Vector2(0,0),Vector2(0,1),Vector2(1,1)],
			[Vector2(0,0),Vector2(1,0),Vector2(2,0)]]
		if absi(seed_value) % 2 == 1:
			shapes[0] = [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(2,1)]
			shapes[1] = [Vector2(1,0),Vector2(0,1),Vector2(1,1)]
		cells.assign(shapes[index])
		source = Vector2(594, 577 + index * 5)
		target = Vector2(1260, 550 + index * 8)
		object_position = source
	elif kind == "cup":
		object_position = CUP_CENTER
	elif kind == "stir":
		object_position = PAN_CENTER + Vector2(PAN_RADIUS.x,0)
	elif kind == "rope":
		rope_routes = [
			_dense([Vector2(807,528),Vector2(1124,584),Vector2(1121,703)]),
			_dense([Vector2(981,496),Vector2(905,600),Vector2(902,691)])]
	queue_redraw()

func cancel() -> void:
	active = false
	visible = false
	paused = false
	captured = false
	pointer_owner = ""
	contact = -1
	amount = 0
	release_ready = false
	settling = 0
	feedback = ""
	swings = 0
	last_edge = 0
	stir_angle = 0
	stir_direction = 0
	stir_valid = false
	rope_index = 0
	rope_point = 1

func suspend() -> void:
	paused = true
	cancel_contact()

func cancel_contact() -> void:
	captured = false
	pointer_owner = ""
	contact = -1
	stir_valid = false
	if kind == "loading" and settling <= 0:
		object_position = source
		release_ready = false

func _dense(corners: Array) -> PackedVector2Array:
	var points := PackedVector2Array([corners[0]])
	for i in corners.size() - 1:
		var count := ceili(corners[i].distance_to(corners[i+1]) / 16.0)
		for j in range(1,count+1): points.append(corners[i].lerp(corners[i+1], float(j)/count))
	return points

func progress() -> float:
	if kind == "loading": return 1.0 if release_ready or settling > 0 else 0.0
	if kind == "cup": return minf(1, swings / 3.0)
	if kind == "stir": return minf(1, amount / TAU)
	return (rope_index + (1.0 if release_ready else float(rope_point - 1) / maxf(1, rope_routes[mini(rope_index,1)].size()-1))) / 2.0 if not rope_routes.is_empty() else 0.0

func hint() -> String:
	if settling > 0: return {"loading":"箱组已对齐 · 正在落位", "cup":"茶汤看清了 · 记下观察", "stir":"翻茶完成 · 收好工具", "rope":"两道绳已收紧 · 封箱完成"}.get(kind, "完成")
	if feedback != "": return feedback
	match kind:
		"loading": return "轮廓已对齐，松手装妥" if release_ready else "按住岸上箱组 → 拖入船上同形轮廓 → 松手"
		"cup": return "轻晃完成，松手看结果" if release_ready else "按住茶杯，左右轻晃 · %d / 3次" % swings
		"stir": return "翻茶完成，松手收铲" if release_ready else "按住竹铲，沿茶盘绕一圈 · %d%%" % roundi(progress()*100)
	return "这道绳画好了，松手收紧" if release_ready else "从亮点沿绳路描画 · 第%d / 2道" % (rope_index+1)

func _start_hit(point: Vector2) -> bool:
	match kind:
		"loading":
			for cell in cells:
				if Rect2(object_position + cell * CELL, BOX_SIZE).grow(12).has_point(point): return true
		"cup": return Rect2(object_position - Vector2(115,95), Vector2(230,190)).has_point(point)
		"stir": return point.distance_to(object_position) <= 94
		"rope": return point.distance_to(rope_routes[rope_index][maxi(0,rope_point-1)]) <= 38
	return false

func handle_event(event: InputEvent) -> bool:
	if not active or paused or settling > 0: return false
	var input_source := "touch" if event is InputEventScreenTouch or event is InputEventScreenDrag else "mouse"
	var id: int = event.index if input_source == "touch" else -1
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			if captured:
				# A few Windows drivers start with mouse-down, then report the same finger.
				if input_source == "touch" and pointer_owner == "mouse" and event.position.distance_to(last_pointer) < 96:
					pointer_owner = input_source
					contact = id
				return true
			if not _start_hit(event.position): return false
			captured = true
			pointer_owner = input_source
			contact = id
			last_pointer = event.position
			grab_offset = event.position - object_position
			feedback = ""
			stir_valid = false
			if kind == "stir": _stir(event.position)
			return true
		if not captured: return false
		if input_source != pointer_owner or id != contact: return true
		if event is InputEventScreenTouch and event.canceled:
			cancel_contact()
			return true
		_move(event.position)
		_release()
		return true
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not captured: return false
		if pointer_owner == input_source and contact == id: _move(event.position)
		return true
	return false

func _move(point: Vector2) -> void:
	feedback = ""
	if kind == "loading":
		object_position = (point - grab_offset).clamp(Vector2(480,425),Vector2(1575,700))
		release_ready = object_position.distance_to(target) <= FIT_DISTANCE
	elif kind == "cup":
		object_position = (point - grab_offset).clamp(CUP_CENTER-Vector2(130,35),CUP_CENTER+Vector2(130,35))
		var edge := -1 if object_position.x < CUP_CENTER.x-80 else (1 if object_position.x > CUP_CENTER.x+80 else 0)
		if edge != 0:
			if last_edge != 0 and last_edge != edge: swings = mini(3,swings+1)
			last_edge = edge
		release_ready = swings >= 3
	elif kind == "stir": _stir(point)
	elif kind == "rope" and not release_ready:
		if last_pointer.distance_to(point) < 1.5: return
		# Interpolate a sparse device event, but require visiting every point in order.
		var count := maxi(1,ceili(last_pointer.distance_to(point)/8.0))
		for i in range(1,mini(count,240)+1):
			var sample := last_pointer.lerp(point, float(i)/count)
			var path := rope_routes[rope_index]
			if sample.distance_to(path[rope_point]) <= 25:
				rope_point += 1
				if rope_point >= path.size():
					rope_point = path.size()-1
					release_ready = true
					break
		if not release_ready and point.distance_to(rope_routes[rope_index][rope_point-1]) > 65:
			feedback = "沿虚线慢慢走，可回到亮点继续"
	last_pointer = point
	queue_redraw()

func _stir(point: Vector2) -> void:
	var normalized := (point - PAN_CENTER) / PAN_RADIUS
	object_position = point.clamp(Vector2(730,432),Vector2(1180,598))
	if normalized.length() < 0.5 or normalized.length() > 1.45:
		stir_valid = false
		feedback = "把竹铲带回茶盘，沿椭圆继续翻茶"
		return
	var angle := normalized.angle()
	if stir_valid:
		var delta := wrapf(angle-stir_angle,-PI,PI)
		if absf(delta) <= 1.05:
			if (stir_direction == 0 or amount <= 0.025) and absf(delta) > 0.04: stir_direction = signf(delta)
			amount = clampf(amount+delta*stir_direction,0,TAU)
		release_ready = amount >= TAU-0.025
	stir_angle = angle
	stir_valid = true

func _release() -> void:
	captured = false
	pointer_owner = ""
	contact = -1
	stir_valid = false
	if not release_ready:
		if kind == "loading":
			object_position = source
			feedback = "还没对上轮廓，箱组已放回岸上，再试一次"
		queue_redraw()
		return
	if kind == "rope" and rope_index == 0:
		rope_index = 1
		rope_point = 1
		release_ready = false
		feedback = "第一道已收紧，接着描画第二道绳"
	else:
		if kind == "loading": object_position = target
		settling = 0.4
	queue_redraw()

func _process(delta: float) -> void:
	if not active or paused: return
	if settling > 0:
		settling -= delta
		if settling <= 0:
			active = false
			completed.emit()
	queue_redraw()

func _line(points: PackedVector2Array, color: Color, width: float = 3) -> void:
	if points.size() > 1: draw_polyline(points,color,width,true)

func _draw() -> void:
	if not active: return
	var gold := Color("e5c580")
	var green := Color("acd6a2")
	if kind == "loading":
		for i in loaded:
			draw_texture_rect(texture,Rect2(Vector2(1400+i%4*42,683+floori(i/4.0)*19),Vector2(59,39)),false)
		for cell in cells:
			var at := target + cell * CELL
			draw_texture_rect(texture,Rect2(at,BOX_SIZE),false, Color(0.78,0.92,0.75,0.32) if release_ready else Color(1,0.85,0.55,0.26))
			_line(PackedVector2Array([at+Vector2(12,24),at+Vector2(67,1),at+Vector2(114,19),at+Vector2(114,58),at+Vector2(57,79),at+Vector2(12,62),at+Vector2(12,24)]),green if release_ready else gold,3)
		for cell in cells:
			var at := object_position + cell * CELL
			draw_texture_rect(texture,Rect2(at,BOX_SIZE),false)
			if captured: draw_arc(at+BOX_SIZE/2,18,0,TAU,32,Color(0.96,0.83,0.53,0.6),2,true)
		if font:
			draw_rect(Rect2(source+Vector2(-8,-62),Vector2(296,48)),Color(0.06,0.11,0.08,0.93))
			draw_rect(Rect2(target+Vector2(-8,-62),Vector2(282,48)),Color(0.06,0.11,0.08,0.93))
			draw_string(font,source+Vector2(0,-24),"岸上 · 拖动整组%d箱" % cells.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,25,gold)
			draw_string(font,target+Vector2(0,-24),"船上 · 对齐轮廓",HORIZONTAL_ALIGNMENT_LEFT,-1,25,green if release_ready else gold)
	elif kind == "cup":
		draw_line(CUP_CENTER-Vector2(130,0),CUP_CENTER+Vector2(130,0),Color(0.89,0.77,0.49,0.65),4,true)
		for side in [-1,1]: draw_arc(CUP_CENTER+Vector2(side*120,0),28,0,TAU,48,gold,3,true)
		draw_set_transform(object_position,(object_position.x-CUP_CENTER.x)*0.0008)
		if cup: draw_texture_rect(cup,Rect2(Vector2(-130,-115),Vector2(260,260)),false)
		else:
			draw_circle(Vector2.ZERO,75,Color("eee4cb"))
			draw_circle(Vector2.ZERO,62,Color("a7692a"))
		draw_set_transform(object_position+Vector2(0,-18),0,Vector2(1,0.34))
		for i in 3: draw_arc(Vector2.ZERO,20+i*13,0,TAU,48,Color(0.98,0.81,0.50,0.45 if captured else 0.15),2,true)
		draw_set_transform(Vector2.ZERO)
	elif kind == "stir":
		var path := PackedVector2Array()
		var direction := stir_direction if stir_direction != 0 else 1.0
		for i in 81: path.append(PAN_CENTER+Vector2(cos(i*TAU/80),sin(i*TAU/80)*direction)*PAN_RADIUS)
		_line(path,Color(0.90,0.80,0.58,0.58),3)
		_line(path.slice(0,maxi(2,int(progress()*80)+1)),green,5)
		for i in 45:
			var at := PAN_CENTER+Vector2(sin(i*13.1+amount)*145,cos(i*7.3+amount)*35)
			draw_line(at,at+Vector2(12,4),Color("71643b"),4,true)
		draw_set_transform(object_position, sin(stir_angle)*0.2)
		draw_texture_rect(paddle,Rect2(-Vector2(88,61),Vector2(176,122)),false)
		draw_set_transform(Vector2.ZERO)
	else:
		for route in 2:
			var path := rope_routes[route]
			for i in path.size()-1:
				if i%2 == 0: draw_line(path[i],path[i+1],Color(0.98,0.87,0.60,0.72),4,true)
			if route < rope_index: _line(path,green,7)
			elif route == rope_index:
				_line(path.slice(0,rope_point+1 if release_ready else rope_point),gold,7)
				draw_circle(path[rope_point-1],17,green)
				draw_arc(path[-1],18,0,TAU,40,gold,4,true)
				if font: draw_string(font,path[0]+Vector2(-20,-28),"起点" if rope_point == 1 else "接着画",HORIZONTAL_ALIGNMENT_LEFT,-1,23,gold)
