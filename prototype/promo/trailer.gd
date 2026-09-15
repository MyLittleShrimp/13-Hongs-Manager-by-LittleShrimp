extends Control
## 60-second film director. Uses real game scenes, actions and seeded outcomes.
## This scene is launched explicitly; it never replaces the game's main scene.
const Trade = preload("res://scripts/trade_session.gd")
const FPS := 30
const GOLD := Color("dabd83")
const PAPER := Color("f6efdf")
const INK := Color("091b15")
const SHOTS := [
	{"start":0.0,"end":5.0,"scene":"title","head":"十三行 · 茶船将发","sub":"一笔茶单，一段由你作主的生意。","tag":"二维剧情策略经营游戏"},
	{"start":5.0,"end":10.0,"scene":"intro","head":"接过账本，做一回采购管事","sub":"从第一笔茶单，走进十三行的贸易故事。","tag":"角色与剧情"},
	{"start":10.0,"end":16.0,"scene":"market","head":"挑货、议价，先算好这笔账","sub":"货源、报价和船期，每一步都要权衡。","tag":"采买决策"},
	{"start":16.0,"end":23.0,"scene":"inspection_work","head":"亲手验茶，看清这批货的成色","sub":"看叶形 · 辨干湿 · 看汤色","tag":"场景操作"},
	{"start":23.0,"end":30.0,"scene":"roast_plan","head":"选火候，再把茶货细细照应","sub":"常火、慢火、快火，时间与成本各有取舍。","tag":"加工与补救"},
	{"start":30.0,"end":36.0,"scene":"packing_work","head":"从一张衬料，到十箱茶封妥","sub":"铺衬料 · 装茶货 · 合盖扎绳","tag":"亲手封箱"},
	{"start":36.0,"end":42.0,"scene":"voyage","head":"风雨难料，生意也有风险","sub":"靠岸避风，还是赶上船期？","tag":"随机事件"},
	{"start":42.0,"end":47.0,"scene":"acceptance","head":"到了码头，生意还要继续谈","sub":"货色不足：折价成交，还是转售止损？","tag":"交接与选择"},
	{"start":47.0,"end":50.0,"scene":"profit","head":"赚与亏，没有预设的答案","sub":"货色、成本、工期与运气，共同写下结果。","tag":"真实盈亏"},
	{"start":50.0,"end":53.0,"scene":"loss","head":"赚与亏，没有预设的答案","sub":"一次决定，一份代价，也是一段新的经历。","tag":"真实盈亏"},
	{"start":53.0,"end":60.0,"scene":"outro","head":"十三行 · 茶船将发","sub":"你的第一单，会如何收场？","tag":"单机茶叶篇 · 游戏实机演示"}
]

var game
var game_view: SubViewport
var footage: TextureRect
var titles: Control
var curtain: ColorRect
var marks
var font_body: SystemFont
var font_title: SystemFont
var frames := 0
var shot_index := -1
var actions_done := {}
var config: Dictionary
var seed_profit := -1
var seed_loss := -1
var click_age := 10.0
var click_position := Vector2.ZERO
var cinematic := false
var current_time := 0.0

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/trade_v2.json"))
	_find_scenarios()
	font_body = SystemFont.new()
	font_body.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font_title = SystemFont.new()
	font_title.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC", "serif"])
	game_view = SubViewport.new()
	game_view.size = Vector2i(1920,1080)
	game_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(game_view)
	game = load("res://scenes/main.tscn").instantiate()
	game_view.add_child(game)
	game.test_mode = true
	game.logger.enabled = false
	game.ambient_enabled = false
	footage = TextureRect.new()
	footage.texture = game_view.get_texture()
	footage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	footage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footage)
	titles = Control.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titles)
	marks = load("res://promo/film_marks.gd").new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marks)
	curtain = ColorRect.new()
	curtain.position = Vector2.ZERO
	curtain.size = Vector2(1920,1080)
	curtain.color = INK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	_set_shot(0)
	print("PROMO_SCENARIOS: profit_seed=%d loss_seed=%d; all outcomes resolved by game model" % [seed_profit,seed_loss])
	var manifest := {"fps":FPS,"seconds":60,"width":1920,"height":1080,"audio":false,
		"game_version":"0.4","profit_seed":seed_profit,"loss_seed":seed_loss,"shots":SHOTS,
		"notes":"Curated real seeded playthroughs; shots condensed for trailer. No fabricated prices, damage or profits."}
	var output_dir := OS.get_environment("HONGS_PROMO_OUTPUT")
	if output_dir == "": output_dir = ProjectSettings.globalize_path("res://../artifacts/promo-v1")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("capture_manifest.json"), FileAccess.WRITE)
	assert(file != null,"Could not write capture manifest")
	file.store_string(JSON.stringify(manifest, "  "))

func _find_scenarios() -> void:
	for seed_value in 3000:
		if seed_profit < 0:
			var bought = _at(seed_value,"inspection",false)
			if bought.quality >= 74 and bought.quality <= 82:
				var success = _at(seed_value,"result",false)
				if success.result.contract_met and success.result.profit > 0: seed_profit = seed_value
		if seed_loss < 0:
			var failure = _at(seed_value,"result",true)
			if failure.result.profit < 0 and failure.result.damaged and failure.cargo_event == "squall": seed_loss = seed_value
		if seed_profit >= 0 and seed_loss >= 0: return
	assert(false,"Could not find real representative outcomes")

func _at(seed_value: int, target: String, risky: bool):
	var t = Trade.new(config)
	t.reset(seed_value)
	if target == "attract": return t
	t.start()
	for iteration in 90:
		if t.stage == target: return t
		var ok := false
		match t.stage:
			"intro": ok = t.choose(0)
			"contract": ok = t.choose(2)
			"market", "bargain": ok = t.choose(0)
			"inspection": ok = t.choose(2)
			"inspection_work":
				for i in 3: assert(t.choose(i))
				ok = t.finish_inspection()
			"remedy": ok = t.choose(1 if t.rework_count == 0 and t.quality < 100 else 0)
			"roast_plan": ok = t.choose(0)
			"roasting_work":
				assert(t.select_tool(t.roast_step))
				ok = t.choose(0)
			"shipment_review": ok = t.choose(1)
			"packing": ok = t.choose(0 if risky else 1)
			"packing_work":
				assert(t.select_tool(t.packing_step))
				ok = t.choose(0)
			"packing_seal", "voyage_report", "acceptance", "arrival": ok = t.choose(0)
			"dock": ok = t.choose(0 if risky else 1)
			"voyage": ok = t.choose(1)
		assert(ok,"Invalid trailer action: " + t.stage)
	assert(false,"Trailer target not reached: " + target)
	return t

func _set_shot(index: int) -> void:
	shot_index = index
	actions_done.clear()
	var shot: Dictionary = SHOTS[index]
	var target: String = shot.scene
	var risky := target in ["voyage","acceptance","loss"]
	if target in ["title","outro"]: target = "attract"
	elif target in ["profit","loss"]: target = "result"
	game.model = _at(seed_loss if risky else seed_profit, target, risky)
	game._render()
	if is_instance_valid(game.scene_fade): game.scene_fade.visible = false
	cinematic = shot.scene in ["title","intro","outro"]
	game.page.visible = not cinematic
	if cinematic:
		footage.position = Vector2.ZERO
		footage.size = Vector2(1920,1080)
	else:
		footage.position = Vector2(168,165)
		footage.size = Vector2(1584,891)
	for child in titles.get_children():
		titles.remove_child(child)
		child.queue_free()
	_build_titles(shot)

func _text(value: String, box: Rect2, font_size: int, color: Color, serif: bool = false) -> Label:
	var label := Label.new()
	label.position = box.position
	label.size = box.size
	label.text = value
	label.add_theme_font_override("font", font_title if serif else font_body)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.6))
	label.add_theme_constant_override("shadow_offset_y",2)
	titles.add_child(label)
	return label

func _shade(box: Rect2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = box.position
	rect.size = box.size
	rect.color = color
	titles.add_child(rect)

func _build_titles(shot: Dictionary) -> void:
	if cinematic:
		if shot.scene in ["title","outro"]:
			for i in 64:
				_shade(Rect2(i * 30,0,31,1080), Color(0.025,0.065,0.045,pow(1.0-i/64.0,1.6)*0.88))
			_text(shot.tag,Rect2(138,280,1080,55),28,GOLD)
			_text(shot.head,Rect2(129,380,1240,126),86,PAPER,true)
			_shade(Rect2(140,541,114,3),GOLD)
			_text(shot.sub,Rect2(140,588,1170,88),44,PAPER)
			_text("七处场景 · 五位角色 · 一单由你经营的茶生意",Rect2(143,868,1170,52),27,GOLD)
		else:
			for i in 40:
				_shade(Rect2(0,640+i*11,1920,12),Color(0.025,0.065,0.045,i/40.0*0.94))
			_text(shot.head,Rect2(132,818,1640,88),58,PAPER,true)
			_text(shot.sub,Rect2(137,932,1600,62),32,GOLD)
	else:
		_shade(Rect2(168,140,1584,2),Color(0.85,0.72,0.48,0.5))
		_text(shot.head,Rect2(168,23,1460,60),43,PAPER,true)
		_text(shot.sub,Rect2(172,91,1360,41),26,GOLD)
		_text(shot.tag,Rect2(1574,38,245,36),22,GOLD)
		_text("游戏实机",Rect2(32,1002,125,42),19,Color("8d9c8b"))
	_shade(Rect2(0,1076,1920,4),Color(0.09,0.16,0.12,1))

func _click(id: String) -> void:
	assert(game.ui_buttons.has(id),"Missing trailer button: " + id)
	var button: Button = game.ui_buttons[id]
	assert(not button.disabled,"Disabled trailer button: " + id)
	var point := button.get_global_rect().get_center()
	click_position = footage.position + point * (footage.size / Vector2(1920,1080))
	click_age = 0
	button.pressed.emit()
	game.page.visible = not cinematic

func _cue(key: String, at: float, local_time: float, id: String) -> void:
	if local_time >= at and not actions_done.has(key):
		actions_done[key] = true
		_click(id)

func _process(delta: float) -> void:
	current_time = float(frames) / FPS
	frames += 1
	if current_time >= 60:
		print("PROMO_CAPTURE_PASS: 1800 frames, 60 seconds, live Godot scene animation, silent")
		get_tree().quit(0)
		return
	click_age += delta
	marks.progress = current_time / 60.0
	marks.click_age = click_age
	marks.point = click_position
	marks.cinematic = cinematic
	var index := 0
	for i in SHOTS.size():
		if current_time >= float(SHOTS[i].start): index = i
	if index != shot_index: _set_shot(index)
	var shot: Dictionary = SHOTS[shot_index]
	var local_time := current_time - float(shot.start)
	var remaining := float(shot.end) - current_time
	curtain.modulate.a = maxf(clampf(1-local_time/0.28,0,1),clampf(1-remaining/0.24,0,1))
	if cinematic:
		var progress := local_time / (float(shot.end)-float(shot.start))
		var zoom := 1.025 + progress * 0.025
		footage.size = Vector2(1920,1080) * zoom
		footage.position = -(footage.size-Vector2(1920,1080))*Vector2(0.67,0.44)
	match str(shot.scene):
		"market":
			_cue("pick",2.0,local_time,"choice_0")
			_cue("buy",4.4,local_time,"choice_0")
		"inspection_work":
			_cue("leaf",0.8,local_time,"observe_0")
			_cue("dry",2.5,local_time,"observe_1")
			_cue("cup",4.2,local_time,"observe_2")
			_cue("record",5.7,local_time,"inspection_done")
		"roast_plan":
			_cue("plan",0.8,local_time,"choice_0")
			_cue("tool0",1.3,local_time,"tool_0")
			_cue("act0",2.0,local_time,"work_action")
			_cue("tool1",2.8,local_time,"tool_1")
			_cue("act1",3.5,local_time,"work_action")
			_cue("tool2",4.3,local_time,"tool_2")
			_cue("act2",5.1,local_time,"work_action")
		"packing_work":
			_cue("tool0",0.4,local_time,"tool_0")
			_cue("act0",1.1,local_time,"pack_action")
			_cue("tool1",1.9,local_time,"tool_1")
			_cue("act1",2.6,local_time,"pack_action")
			_cue("tool2",3.4,local_time,"tool_2")
			_cue("act2",4.1,local_time,"pack_action")
		"voyage":
			_cue("risk",3.2,local_time,"choice_1")
		"acceptance":
			_cue("agree",3.2,local_time,"choice_0")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1920,1080),INK)
