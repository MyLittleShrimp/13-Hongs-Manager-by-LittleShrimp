extends "res://scripts/gesture_workshop.gd"
## The remaining workshop actions share the same single-pointer ownership and commit gate.
var tools: Array[Texture2D] = []
var phase := 0
var home := Vector2.ZERO
var sides := 0
var left_extent := 0.0
var right_extent := 0.0
var pickup_pending := false
var dwell := 0.0
var lid_closed := false
var clue := ""
var idle_age := 0.0
var demonstrated := false
const LEAVES := Vector2(840, 539)
const PINCH := Vector2(986, 534)
const FIRE := Vector2(955, 650)
const COLLECT := Vector2(1060, 537)
const COOL := Vector2(1212, 684)
const BOX := Vector2(967, 557)
const POUR := Vector2(1017, 435)
const WIPE_START := Vector2(837, 557)
const WIPE_END := Vector2(1087, 557)
const CRAFTS := ["spread", "knead", "fire", "sieve", "liner", "pour", "seal"]

func _ready() -> void:
	super._ready()
	for i in 6:
		var item := AtlasTexture.new()
		item.atlas = paddle.atlas
		var size := item.atlas.get_size() / Vector2(3,2)
		item.region = Rect2(Vector2((i%3)*size.x, floori(i/3.0)*size.y), size)
		item.filter_clip = true
		tools.append(item)

func cancel() -> void:
	super.cancel()
	phase = 0
	sides = 0
	left_extent = 0
	right_extent = 0
	pickup_pending = false
	dwell = 0
	lid_closed = false
	clue = ""
	idle_age = 0
	demonstrated = false

func begin(mode: String, index: int, seed_value: int = 0, already_loaded: int = 0) -> void:
	super.begin(mode,index,seed_value,already_loaded)
	match kind:
		"spread": object_position = LEAVES
		"knead": object_position = PINCH
		"fire": object_position = FIRE
		"sieve": object_position = Vector2(1230,565)
		"liner": object_position = Vector2(1260,610)
		"pour": object_position = Vector2(1240,563)
		"seal":
			object_position = Vector2(1255,628)
			_setup_rope()
	home = object_position

func pickup_from_tray(event: InputEvent) -> void:
	# Transfer the original down event, without requiring a release and another click.
	captured = true
	pointer_owner = "touch" if event is InputEventScreenTouch else "mouse"
	contact = event.index if pointer_owner == "touch" else -1
	last_pointer = event.position
	grab_offset = Vector2.ZERO
	object_position = event.position
	pickup_pending = kind in ["fire", "stir"]
	demonstrated = true
	queue_redraw()

func cancel_contact() -> void:
	super.cancel_contact()
	if kind in ["spread","fire"]: phase = 0
	if kind == "knead": last_edge = 0
	pickup_pending = false
	dwell = 0
	if settling <= 0 and kind in ["fire", "stir", "sieve", "liner", "pour", "seal"]:
		object_position = COLLECT if kind == "sieve" and phase == 1 else home
		if kind in ["sieve", "seal"] or (kind == "liner" and phase == 0): release_ready = false
	queue_redraw()

func handle_event(event: InputEvent) -> bool:
	var was_captured := captured
	var handled := super.handle_event(event)
	if not was_captured and captured:
		if kind in ["spread","fire"]: phase = 0
		if kind == "knead": last_edge = 0
	if handled:
		idle_age = 0
		demonstrated = true
	return handled

func progress() -> float:
	match kind:
		"spread", "fire": return (left_extent + right_extent) / 2.0
		"knead": return minf(1,swings/4.0)
		"sieve": return 1.0 if release_ready else (0.55 if phase == 1 else dwell*0.5/0.4)
		"liner": return 0.45 + amount*0.55 if phase == 1 else (0.35 if release_ready else 0.0)
		"pour": return amount
		"seal": return 0.2 if release_ready else 0.0
	return super.progress()

func hint() -> String:
	if kind not in CRAFTS and not pickup_pending: return super.hint()
	if settling > 0:
		return {"spread":"茶样已摊开 · 记下叶形", "knead":"轻捻完成 · 记下干湿", "fire":"炭火已拨匀 · 接着翻茶", "sieve":"正在回凉 · 收好后查看货色", "liner":"衬料已铺平 · 接着装茶", "pour":"茶货已装妥 · 接着合盖"}.get(kind,"完成")
	if pickup_pending: return "把工具拖到亮起的操作区，直接开始"
	if feedback != "": return feedback
	match kind:
		"spread": return "茶样已摊开，松手看结果" if release_ready else "按住茶样，从中间向两侧拨开"
		"knead": return "轻捻完成，松手看结果" if release_ready else "按住这撮茶叶，短距离来回轻捻 · %d / 2回" % (swings/2)
		"fire": return "炭火拨匀了，松手收钳" if release_ready else "按住火钳，从中间向两侧拨匀炭火"
		"sieve": return "回凉处已对齐，松手放下" if release_ready else ("茶已接好，移到右下方回凉处" if phase == 1 else "把竹筛移到接茶圈，稍停片刻")
		"liner": return ("衬料已抹平，松手完成" if release_ready else "从亮点向右抹平衬纸") if phase == 1 else ("松手展开衬料" if release_ready else "按住衬料，拖入箱口轮廓")
		"pour": return "茶货已装满，松手收篓" if release_ready else "把茶篓移到箱口上方，停一停 · %d%%" % roundi(amount*100)
		"seal": return "箱盖已对齐，松手合盖" if release_ready else "把箱盖拖到箱口，松手后接着封绳"
	return ""

func dialogue() -> Array:
	var lines := {
		"spread":"把茶样轻轻拨开，看看叶形齐不齐。两边都摊开，再作判断。",
		"knead":"按住这一撮茶，轻轻来回捻两回。看清干爽还是潮软，再记下来。",
		"fire":"用火钳把中间的炭火向两边拨匀，让茶受热均匀。不用急着来回猛划。",
		"sieve":"先把筛移到接茶处，停一停。接好茶，再放到桌边回凉。",
		"liner":"把衬料铺进箱里，再从亮点抹平。中途松手，已经铺好的不会丢。",
		"pour":"茶篓移到箱口，稳住一会儿，茶就倒进去了。装到线便停，不用抢快。",
		"seal":"先把箱盖放稳。合好盖，再沿两道绳路收紧。",
		"rope":"从亮点起，沿着绳路滑过去。先收紧一道，再来一道；中途松手，也能接着画。",
		"loading":"把这一组箱子拖到船上同样的轮廓里。放稳再松手，没对上就再试一次。",
		"cup":"捧住茶杯，轻轻左右晃动，看看汤色与清浊。不用急。",
		"stir":"按住竹铲，沿茶盘慢慢绕一圈，把茶翻匀。手速快慢不影响货色。"}
	return ["阿顺" if kind == "loading" else ("梁老板" if kind in ["spread","knead","cup"] else "陈叔"),lines.get(kind,"")]

func _start_hit(point: Vector2) -> bool:
	match kind:
		"spread": return Rect2(LEAVES-Vector2(160,85),Vector2(320,170)).has_point(point)
		"knead": return Rect2(PINCH-Vector2(110,75),Vector2(220,150)).has_point(point)
		"fire", "sieve", "pour", "seal": return point.distance_to(object_position) < 108
		"liner": return point.distance_to(WIPE_START.lerp(WIPE_END,amount)) < 65 if phase == 1 else point.distance_to(object_position) < 105
	return super._start_hit(point)

func _sweep(point: Vector2, center: Vector2) -> void:
	if absf(point.y-center.y) > 70 or absf(last_pointer.y-center.y) > 90: return
	# Each side needs a continuous sweep out from the center; merely touching an endpoint does not count.
	var nearest := Geometry2D.get_closest_point_to_segment(center,last_pointer,point)
	if nearest.distance_to(center) < 45: phase = 1
	if phase != 1: return
	var extent := clampf(absf(point.x-center.x)/125.0,0,1)
	if point.x < center.x: left_extent = maxf(left_extent,extent)
	else: right_extent = maxf(right_extent,extent)
	release_ready = left_extent >= 1 and right_extent >= 1

func _move(point: Vector2) -> void:
	if pickup_pending:
		object_position = point
		if point.distance_to(home) < 95:
			pickup_pending = false
			grab_offset = Vector2.ZERO
			last_pointer = point
			if kind == "stir": _stir(point)
		queue_redraw()
		return
	if kind not in CRAFTS:
		super._move(point)
		return
	feedback = ""
	match kind:
		"spread": _sweep(point,LEAVES)
		"knead":
			if point.distance_to(last_pointer) < 2: return
			if absf(point.y-PINCH.y) < 75 and absf(point.x-PINCH.x) < 130:
				var edge := -1 if point.x < PINCH.x-26 else (1 if point.x > PINCH.x+26 else 0)
				if edge != 0:
					if last_edge != 0 and last_edge != edge: swings = mini(4,swings+1)
					last_edge = edge
				amount = clampf((point.x-PINCH.x)/70.0,-1,1)
				release_ready = swings >= 4
		"fire":
			object_position = point.clamp(Vector2(750,592),Vector2(1150,705))
			_sweep(point,FIRE)
		"sieve", "liner", "pour", "seal":
			if kind == "liner" and phase == 1:
				var previous := WIPE_START.lerp(WIPE_END,amount)
				if absf(point.y-WIPE_START.y) < 48 and absf(last_pointer.y-WIPE_START.y) < 65 and last_pointer.distance_to(previous) < 70:
					amount = maxf(amount,clampf((point.x-WIPE_START.x)/(WIPE_END.x-WIPE_START.x),0,1))
				release_ready = amount >= 1
			else:
				object_position = (point-grab_offset).clamp(Vector2(610,395),Vector2(1430,745))
				if kind == "sieve": release_ready = phase == 1 and object_position.distance_to(COOL) < 65
				elif kind in ["liner","seal"]: release_ready = object_position.distance_to(BOX) < 68
	last_pointer = point
	queue_redraw()

func _release() -> void:
	if pickup_pending:
		cancel_contact()
		return
	if kind not in CRAFTS:
		super._release()
		return
	captured = false
	pointer_owner = ""
	contact = -1
	dwell = 0
	if kind in ["spread","fire"]: phase = 0
	if not release_ready:
		if kind in ["sieve","liner","pour","seal"] and not (kind == "liner" and phase == 1):
			object_position = COLLECT if kind == "sieve" and phase == 1 else home
			feedback = "已接好茶，重新按住竹筛移到回凉处" if kind == "sieve" and phase == 1 else "已放回台边，重新按住继续"
		queue_redraw()
		return
	if kind == "liner" and phase == 0:
		phase = 1
		object_position = BOX
		release_ready = false
		feedback = "衬料已展开，从亮点向右抹平"
	elif kind == "seal":
		kind = "rope"
		lid_closed = true
		phase = 1
		release_ready = false
		feedback = "箱盖合好了，从亮点开始封绳"
	else:
		if kind == "sieve": object_position = COOL
		settling = 0.9 if kind == "sieve" else 0.4
	queue_redraw()

func packing_progress() -> float:
	if kind == "liner": return 0.75 + amount*0.25 if phase == 1 else 0.0
	if kind == "pour": return amount
	return 1.0 if kind == "rope" else 0.0

func _process(delta: float) -> void:
	if active and not paused:
		idle_age += delta
		if captured and settling <= 0:
			if kind == "pour" and object_position.distance_to(POUR) < 68:
				amount = minf(1,amount+minf(delta,0.1)/1.1)
				release_ready = amount >= 1
			elif kind == "sieve" and phase == 0:
				dwell = dwell+minf(delta,0.1) if object_position.distance_to(COLLECT) < 68 else 0.0
				if dwell >= 0.4:
					phase = 1
					dwell = 0
					feedback = "茶已接好，继续移到右下方回凉处"
	super._process(delta)

func _tool(index: int, at: Vector2, size: Vector2, angle: float = 0) -> void:
	draw_set_transform(at,angle)
	draw_texture_rect(tools[index],Rect2(-size/2,size),false)
	draw_set_transform(Vector2.ZERO)

func _tag(at: Vector2, label: String) -> void:
	if not font: return
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x+24
	draw_style_box(_tag_style(),Rect2(at-Vector2(width/2,28),Vector2(width,38)))
	draw_string(font,at-Vector2(width/2-12,1),label,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("eddbad"))

func _tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.10,0.075,0.93)
	style.set_corner_radius_all(6)
	return style

func _guide(at: Vector2, radius: Vector2, good: bool = false) -> void:
	draw_set_transform(at,0,radius/Vector2(100,100))
	draw_circle(Vector2.ZERO,100,Color(0.67,0.80,0.53,0.08))
	draw_arc(Vector2.ZERO,100,0,TAU,70,Color("abd3a1") if good else Color("ddc184"),3,true)
	draw_set_transform(Vector2.ZERO)

func _leaf(at: Vector2, angle: float, size: float, broken: bool = false) -> void:
	draw_set_transform(at,angle,Vector2.ONE*size)
	draw_colored_polygon(PackedVector2Array([Vector2(-15,0),Vector2(-5,-5),Vector2(14,0),Vector2(-4,5)]),Color("756740") if broken else Color("4b502d"))
	draw_line(Vector2(-10,0),Vector2(8 if broken else 12,0),Color("baaa71"),1.3,true)
	draw_set_transform(Vector2.ZERO)

func _sample_base(at: Vector2, radius: Vector2) -> void:
	draw_set_transform(at,0,radius/Vector2(100,100))
	draw_circle(Vector2.ZERO,100,Color("b69861"))
	draw_circle(Vector2.ZERO,94,Color("e0cd9b"))
	draw_arc(Vector2.ZERO,98,0,TAU,70,Color("705238"),3,true)
	draw_set_transform(Vector2.ZERO)

func _cooling_stand() -> void:
	for offset in [Vector2(-98,3),Vector2(89,6)]:
		draw_line(COOL+offset,COOL+offset+Vector2(0,108),Color("493321"),13,true)
	var top := PackedVector2Array([COOL+Vector2(-135,0),COOL+Vector2(-67,-46),COOL+Vector2(137,-9),COOL+Vector2(66,48)])
	draw_colored_polygon(top,Color("966a3f"))
	_line(PackedVector2Array([top[0],top[1],top[2],top[3],top[0]]),Color("543b26"),5)
	for i in 12: draw_line(top[0].lerp(top[1],i/12.0),top[3].lerp(top[2],i/12.0),Color(0.27,0.17,0.09,0.26),2,true)

func _lid(at: Vector2, size: float, aligned: bool) -> void:
	var corners := PackedVector2Array()
	for p in [Vector2(-220,8),Vector2(-83,-81),Vector2(219,-15),Vector2(95,68)]: corners.append(at+p*size)
	draw_colored_polygon(corners,Color("ac8755"))
	_line(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]),Color("b0d4a1") if aligned else Color("60452b"),4)
	for i in 25: draw_line(corners[0].lerp(corners[1],i/25.0),corners[3].lerp(corners[2],i/25.0),Color(0.35,0.23,0.12,0.32),1.5,true)

func _draw() -> void:
	if not active: return
	if kind not in CRAFTS:
		if pickup_pending:
			_guide(home,Vector2(80,42))
			_tool(1,object_position,Vector2(176,122))
		else: super._draw()
		return
	var gold := Color("e6ca8a")
	var green := Color("add4a3")
	match kind:
		"spread":
			_sample_base(LEAVES,Vector2(191,81))
			_guide(LEAVES,Vector2(193,84),release_ready)
			for side in [-1,1]:
				draw_line(LEAVES+Vector2(side*35,0),LEAVES+Vector2(side*145,0),gold,3,true)
				draw_circle(LEAVES+Vector2(side*145,0),12,green if (left_extent if side == -1 else right_extent) >= 1 else gold)
			for i in 30:
				var extent := left_extent if i%2 == 0 else right_extent
				var at := LEAVES+Vector2((1 if i%2 else -1)*(15+i%8*(5+extent*13)),sin(i*6.8)*(20+extent*24))
				_leaf(at,sin(i*12.1),1.15 if i%5 == 0 else 0.8,i%5 == 0 and clue.contains("碎杂"))
			_tag(LEAVES+Vector2(0,112),"从中间向两侧拨开")
		"knead":
			_sample_base(PINCH,Vector2(122,67))
			_guide(PINCH,Vector2(124,69),release_ready)
			for side in [-1,1]: draw_line(PINCH+Vector2(side*35,49),PINCH+Vector2(side*73,49),gold,4,true)
			for i in 5: _leaf(PINCH+Vector2((i-2)*23+amount*12,sin(i*7.1)*12),amount*0.6+i*1.1,1.7,release_ready and clue.contains("干爽"))
			_tag(PINCH+Vector2(0,111),"轻捻 · %d / 2回" % (swings/2))
		"fire":
			_guide(FIRE,Vector2(178,55),release_ready)
			for i in 20:
				var extent := left_extent if i%2 == 0 else right_extent
				var at := FIRE+Vector2((1 if i%2 else -1)*(10+i%10*(4+extent*11)),sin(i*12.1)*20)
				var coal := PackedVector2Array([at+Vector2(-9,-3),at+Vector2(-2,-8),at+Vector2(9,-4),at+Vector2(6,7),at+Vector2(-6,5)])
				draw_colored_polygon(coal,Color("42332a"))
				draw_line(coal[2],coal[3],Color("dd8949"),2,true)
				draw_line(at-Vector2(5,2),at+Vector2(3,3),Color("86664b"),1.5,true)
			_tool(0,object_position,Vector2(184,184),-0.25)
		"sieve":
			_cooling_stand()
			_guide(COLLECT,Vector2(98,48),phase == 1)
			_guide(COOL,Vector2(117,54),release_ready)
			_tag(COLLECT+Vector2(0,-58),"接茶处 · 稍停")
			_tag(COOL+Vector2(0,80),"回凉处 · 松手")
			_tool(2,object_position,Vector2(241,167))
			if phase == 1:
				draw_set_transform(object_position,0,Vector2(1,0.42))
				draw_circle(Vector2.ZERO,83,Color("51452c"))
				draw_set_transform(Vector2.ZERO)
				for i in 70: _leaf(object_position+Vector2(sin(i*13.1)*77,cos(i*7.3)*27),i,0.5)
				for i in 5: draw_arc(object_position+Vector2((i-2)*23,-35-idle_age*7),12,0.2,2.9,18,Color(0.95,0.88,0.69,0.18 if settling <= 0 else settling*0.3),2,true)
		"liner":
			if phase == 0:
				_guide(BOX,Vector2(164,60),release_ready)
				_tool(3,object_position,Vector2(223,160),-0.1)
			else:
				var tip := WIPE_START.lerp(WIPE_END,amount)
				draw_line(WIPE_START,WIPE_END,gold,3,true)
				if amount > 0: draw_line(WIPE_START,tip,green,7,true)
				draw_circle(tip,19,green)
				_tag(BOX+Vector2(0,-100),"从亮点向右抹平")
		"pour":
			var pouring := captured and object_position.distance_to(POUR) < 68
			_guide(POUR,Vector2(91,42),pouring)
			_tool(4,object_position,Vector2(193,167),-0.45 if pouring else -0.08)
			if pouring and amount < 1:
				for i in 18:
					var t := fmod(idle_age*2+i/18.0,1)
					_leaf((object_position+Vector2(-44,29)).lerp(BOX+Vector2(sin(i*8.1)*81,0),t),i,0.4)
			_tag(Vector2(1230,702),"装满后松手收篓")
		"seal":
			_guide(BOX,Vector2(214,77),release_ready)
			_lid(object_position,1.0 if release_ready else 0.64,release_ready)
			_tag(Vector2(1255,738),"按住箱盖，放到箱口")
	if not demonstrated and idle_age > 3 and idle_age < 5.5:
		var start := home
		var finish := BOX if kind in ["liner","seal"] else (POUR if kind == "pour" else (COLLECT if kind == "sieve" else home+Vector2(125,0)))
		draw_arc(start.lerp(finish,(idle_age-3)/2.5),23,0,TAU,40,Color(0.97,0.87,0.58,0.85),3,true)
