extends Control

const TradeSession = preload("res://scripts/trade_session.gd")
const TouchButton = preload("res://scripts/touch_button.gd")
const Actor = preload("res://scripts/actor.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const PackingEffect = preload("res://scripts/packing_effect.gd")
const WorkshopEffect = preload("res://scripts/workshop_effect.gd")
const SessionLog = preload("res://scripts/session_log.gd")
const MusicPlaylist = preload("res://scripts/music_playlist.gd")
const MarketStory = preload("res://scripts/market_story.gd")
const MarketExchange = preload("res://scripts/market_exchange.gd")
const QualityDisplay = preload("res://scripts/quality_display.gd")
const WorkshopPerformance = preload("res://scripts/workshop_performance.gd")
const InputGuard = preload("res://scripts/input_guard.gd")
const MoneyIcon = preload("res://scripts/money_icon.gd")
const INK := Color("22392e")
const PAPER := Color("f4eddd")
const GOLD := Color("d9b879")
const DARK := Color(0.055, 0.10, 0.08, 0.93)
const MUTED := Color("b5bcaa")
const RUST := Color("a84935")

var model
var settings: Dictionary
var avatar_profile: Dictionary
var default_avatar_profile: Dictionary
var character_profiles: Array[Dictionary] = []
var pending_character_id := ""
var character_cards: Dictionary = {}
var character_marks: Dictionary = {}
var logger = SessionLog.new()
var font_body: SystemFont
var font_title: SystemFont
var background: TextureRect
var world: Control
var atmosphere
var player_actor
var npc_actor
var crate: TextureRect
var packing_effect
var workshop_effect
var cargo_group: Node2D
var cargo_sprites: Array[TextureRect] = []
var cargo_base_y := 90.0
var tool_sprite: Sprite2D
var tool_motion: Tween
var page: Control
var overlay: Control
var scene_fade: ColorRect
var dialogue_label: Label
var idle_hint: Label
var ui_buttons: Dictionary = {}
var current_location := ""
var overlay_kind := ""
var primary_touch := -1
var transition_guard := 0.0
var idle_seconds := 0.0
var session_seconds := 0.0
var test_mode := false
var screenshot_mode := false
var dialogue_clock := 0.0
var selected := -1
var toast_text := ""
var ambient_enabled := false
var sound_player: AudioStreamPlayer
var music_player
var music_title_label: Label
var last_choice := ""
var rendered_stage := ""
var market_exchange
var workshop_performance
var action_busy := false
var pending_work: Dictionary = {}
var work_progress: ColorRect
var app_version := str(ProjectSettings.get_setting("application/config/version", "dev"))
var input_guard = InputGuard.new()
var compatibility_mode := false

func _ready() -> void:
	font_body = SystemFont.new()
	font_body.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font_title = SystemFont.new()
	font_title.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC", "serif"])
	var args := OS.get_cmdline_user_args()
	compatibility_mode = "--compatibility" in args
	if compatibility_mode:
		Engine.max_fps = 30
		input_guard.suppression_ms = 1200
	test_mode = "--self-test" in args or "--ui-tour" in args
	screenshot_mode = "--ui-tour" in args
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/kiosk.json"))
	avatar_profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/avatar_profile.json"))
	default_avatar_profile = avatar_profile.duplicate(true)
	character_profiles.append(default_avatar_profile.duplicate(true))
	character_profiles.append(JSON.parse_string(FileAccess.get_file_as_string("res://data/avatar_female.json")))
	model = TradeSession.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/trade_v2.json")))
	if test_mode: model.reset(121)
	logger.configure(settings)
	logger.enabled = not test_mode
	if compatibility_mode:
		logger.record("environment", model.session_id, {"version":app_version, "os":OS.get_name(), "os_version":OS.get_version(), "architecture":Engine.get_architecture_name(), "engine":Engine.get_version_info().string, "max_fps":Engine.max_fps})
	background = _texture(self, "res://assets/backgrounds/counter.png", Rect2(0, 0, 1920, 1080), true)
	world = Control.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	atmosphere = Atmosphere.new()
	world.add_child(atmosphere)
	player_actor = Actor.new()
	player_actor.profile = avatar_profile
	world.add_child(player_actor)
	npc_actor = Actor.new()
	npc_actor.profile = _npc_profile("master")
	world.add_child(npc_actor)
	crate = _texture(world, "res://assets/props/tea_crate.png", Rect2(780, 540, 350, 235))
	packing_effect = PackingEffect.new()
	world.add_child(packing_effect)
	cargo_group = Node2D.new()
	world.add_child(cargo_group)
	for i in 10:
		var item := _texture(cargo_group, "res://assets/props/tea_crate.png", Rect2(715 + (i % 5) * 93, 483 + floori(float(i) / 5) * 87, 140, 94))
		cargo_sprites.append(item)
	workshop_effect = WorkshopEffect.new()
	world.add_child(workshop_effect)
	tool_sprite = Sprite2D.new()
	world.add_child(tool_sprite)
	tool_sprite.visible = false
	workshop_performance = WorkshopPerformance.new()
	world.add_child(workshop_performance)
	workshop_performance.completed.connect(_finish_work_performance)
	market_exchange = MarketExchange.new()
	market_exchange.font = font_body
	world.add_child(market_exchange)
	market_exchange.visible = false
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	music_player = MusicPlaylist.new()
	music_player.output_suppressed = test_mode
	add_child(music_player)
	music_player.track_changed.connect(_update_music_title)
	_render()
	if screenshot_mode: call_deferred("_run_ui_tour")

func set_player_profile(profile: Dictionary) -> bool:
	# Complete body replacement is the first avatar integration; no photo capture or network here.
	var path := str(profile.get("body_texture", ""))
	if not path.begins_with("res://") and not path.begins_with("user://"): return false
	if Actor.resolve_texture(path) == null: return false
	avatar_profile = profile.duplicate(true)
	avatar_profile["display_name"] = str(profile.get("display_name", "阿砚")).left(8)
	player_actor.set_profile(avatar_profile)
	_render()
	return true

func _npc_profile(id: String) -> Dictionary:
	var path := "res://assets/characters/%s.png" % id
	if not ResourceLoader.exists(path): path = "res://assets/characters/steward.png"
	return {"body_texture":path, "height":600, "source_foot":[0.5, 0.96]}

func _process(delta: float) -> void:
	transition_guard = maxf(0, transition_guard - delta)
	if is_instance_valid(workshop_performance):
		workshop_performance.paused = overlay_kind != ""
		player_actor.performance_paused = action_busy and overlay_kind != ""
		npc_actor.performance_paused = player_actor.performance_paused
		if action_busy:
			for actor in [player_actor, npc_actor]:
				if actor.walking and actor.motion and actor.motion.is_valid():
					if workshop_performance.paused: actor.motion.pause()
					else: actor.motion.play()
			if pending_work.get("stage", "") == "roasting_work":
				tool_sprite.position = workshop_performance.tool_position()
				tool_sprite.rotation = workshop_performance.tool_rotation()
			if is_instance_valid(work_progress): work_progress.size.x = 580 * workshop_performance.progress()
	if is_instance_valid(cargo_group) and cargo_group.visible:
		cargo_group.position.y = cargo_base_y + sin(float(Time.get_ticks_msec()) / 550.0) * (4 if model.stage == "voyage" else 0)
	if is_instance_valid(dialogue_label) and overlay_kind == "":
		dialogue_clock += delta
		dialogue_label.visible_characters = -1 if test_mode or action_busy else int(dialogue_clock * 38)
	if model == null or model.stage == "attract" or test_mode: return
	session_seconds += delta
	if not bool(settings.get("kiosk_mode", false)): return
	idle_seconds += delta
	var limit := float(settings.reset_seconds)
	if model.stage == "epilogue" or overlay_kind in ["help", "ledger", "history", "avatar", "support", "audio"]:
		limit = float(settings.reading_reset_seconds)
	elif model.stage == "result":
		limit = float(settings.result_reset_seconds)
	if is_instance_valid(idle_hint):
		idle_hint.visible = idle_seconds >= float(settings.hint_seconds) and overlay_kind == ""
	if idle_seconds >= limit:
		_end_session("completed" if model.stage in ["result", "epilogue"] else "idle_reset")
	elif overlay_kind == "" and idle_seconds >= limit - 15:
		_show_idle()

func _input(event: InputEvent) -> void:
	if input_guard.filter_event(event):
		if compatibility_mode and event is InputEventMouseButton:
			logger.record("input_filtered", model.session_id, {"reason":input_guard.reason, "stage":model.stage})
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if primary_touch == -1: primary_touch = event.index
			elif primary_touch != event.index:
				get_viewport().set_input_as_handled()
				return
		elif primary_touch != event.index:
			get_viewport().set_input_as_handled()
			return
		else: primary_touch = -1
		if overlay_kind != "idle": idle_seconds = 0
	elif event is InputEventScreenDrag:
		if event.index != primary_touch:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if primary_touch != -1:
			get_viewport().set_input_as_handled()
			return
		if overlay_kind != "idle": idle_seconds = 0
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE:
			if overlay_kind != "": _close_overlay()
			elif model.stage != "attract": _show_exit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		primary_touch = -1
		for button in ui_buttons.values():
			if is_instance_valid(button): button.cancel_touch()

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	return s

func _panel(parent: Node, box: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(color, border))
	parent.add_child(p)
	p.position = box.position
	p.size = box.size
	return p

func _rect(parent: Node, box: Rect2, color: Color) -> ColorRect:
	var p := ColorRect.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.color = color
	parent.add_child(p)
	p.position = box.position
	p.size = box.size
	return p

func _label(parent: Node, value: String, box: Rect2, font_size: int = 30, color: Color = PAPER, serif: bool = false) -> Label:
	var label := Label.new()
	label.position = box.position
	label.size = box.size
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font_title if serif else font_body)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	label.position = box.position
	label.size = box.size
	label.set_meta("layout_box", box)
	return label

func _texture(parent: Node, path: String, box: Rect2, cover: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path): t.texture = load(path)
	parent.add_child(t)
	t.position = box.position
	t.size = box.size
	return t

func _button(parent: Node, id: String, value: String, box: Rect2, callback: Callable, primary: bool = false, disabled: bool = false):
	var b = TouchButton.new()
	b.name = id
	b.clip_text = true
	b.text = value
	b.disabled = disabled
	b.add_theme_font_override("font", font_body)
	b.add_theme_font_size_override("font_size", 27)
	b.add_theme_color_override("font_color", INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("878b80"))
	b.add_theme_stylebox_override("normal", _style(GOLD if primary else DARK, GOLD if primary else Color("728371")))
	b.add_theme_stylebox_override("hover", _style(Color("f0d399") if primary else Color("344d3e"), GOLD))
	b.add_theme_stylebox_override("pressed", _style(Color("b9c8a5"), GOLD))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12,0.17,0.14,0.94), Color("596454")))
	parent.add_child(b)
	b.position = box.position
	b.size = box.size
	b.set_meta("layout_box", box)
	b.pressed.connect(_activate_button.bind(b, callback))
	ui_buttons[id] = b
	return b

func _activate_button(button: Button, callback: Callable) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree() or button.disabled: return
	if transition_guard > 0 and not test_mode: return
	if not input_guard.allow_activation(button.get_instance_id()): return
	if compatibility_mode:
		logger.record("button", model.session_id, {"id":str(button.name), "source":input_guard.source, "stage":model.stage})
	callback.call()

func _render() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	ui_buttons.clear()
	dialogue_label = null
	work_progress = null
	idle_hint = null
	dialogue_clock = 0
	_update_world()
	if model.stage == "attract":
		_render_attract()
	else:
		_header()
		if model.stage == "result": _render_result()
		elif model.stage == "epilogue": _render_epilogue()
		else: _render_story()
	rendered_stage = model.stage
	if current_location != "" and is_instance_valid(scene_fade):
		move_child(scene_fade, get_child_count() - 1)

func _update_world() -> void:
	var place: String = model.location()
	var changed := place != current_location
	if changed:
		current_location = place
		background.texture = load("res://assets/backgrounds/%s.png" % place)
		player_actor.position = Vector2(250, 790)
		npc_actor.position = Vector2(1360, 790)
		player_actor.walk_to(Vector2(510, 790), 0.8)
		if is_instance_valid(scene_fade): scene_fade.queue_free()
		scene_fade = _rect(self, Rect2(0, 0, 1920, 1080), Color("14251e"))
		var fade := create_tween()
		fade.tween_property(scene_fade, "modulate:a", 0.0, 0.7)
		transition_guard = 0.75
	var npc_id := "buyer" if model.stage in ["acceptance", "arrival"] else ("boatman" if place in ["dock", "vessel"] else ("steward" if place in ["market", "inspection"] else "master"))
	if model.stage == "remedy" and not model.events.is_empty() and model.events[-1].label == "复焙收茶": npc_id = "master"
	if npc_actor.profile.get("body_texture", "") != "res://assets/characters/%s.png" % npc_id:
		npc_actor.set_profile(_npc_profile(npc_id))
	if model.stage == "attract":
		if player_actor.motion: player_actor.motion.kill()
		player_actor.walking = false
		player_actor.position = Vector2(1390, 920)
		player_actor.visible = true
		npc_actor.visible = false
	else:
		player_actor.visible = true
		npc_actor.visible = true
		if not changed and rendered_stage == "attract":
			player_actor.position = Vector2(250, 790)
			player_actor.walk_to(Vector2(510, 790), 0.8)
		player_actor.speaking = model.stage in ["intro", "remedy", "bargain_chat"]
		if model.stage == "bargain_result": player_actor.speaking = model.bargain_beat == 1
		npc_actor.speaking = not player_actor.speaking
		if place in ["inspection", "roasting", "vessel"]:
			if player_actor.motion: player_actor.motion.kill()
			player_actor.walking = false
			player_actor.position = Vector2(345, 790)
			npc_actor.position = Vector2(1535, 790)
	var scene_scale := 0.80 if place in ["inspection", "roasting", "vessel"] else 1.0
	player_actor.scale = Vector2.ONE * scene_scale
	npc_actor.scale = Vector2.ONE * scene_scale
	atmosphere.place = place
	atmosphere.wet = model.weather > 0 or model.cargo_event in ["squall", "leak"]
	atmosphere.storm = model.cargo_event == "squall"
	crate.visible = place in ["market", "packing", "dock"]
	if model.stage != "bargain_result":
		market_exchange.active = false
		market_exchange.visible = false
	packing_effect.visible = model.stage in ["packing_work", "packing_seal"]
	packing_effect.sealed = model.stage == "packing_seal"
	packing_effect.position = Vector2(967, 557)
	packing_effect.step = model.packing_step
	packing_effect.age = 0
	workshop_effect.configure(model)
	if model.stage not in ["roasting_work", "packing_work"]:
		if tool_motion: tool_motion.kill()
		tool_sprite.visible = false
	cargo_group.visible = model.stage in ["voyage", "voyage_report"]
	cargo_group.position.y = cargo_base_y
	for i in cargo_sprites.size():
		var lost: bool = not model.pending_delivery.is_empty() and i >= int(model.pending_delivery.delivered)
		cargo_sprites[i].modulate = Color("6e5a47") if lost else Color.WHITE
		cargo_sprites[i].rotation = -0.14 if lost else 0.0
		cargo_sprites[i].position.y = 483 + floori(float(i) / 5) * 87 + (28 if lost else 0)
	crate.modulate = Color.WHITE
	crate.position = Vector2(790, 540)
	crate.size = Vector2(350, 235)
	crate.texture = load("res://assets/props/tea_crate.png")
	if place == "market":
		crate.position = Vector2(740, 500)
		crate.size = Vector2(440, 293)
	elif model.stage in ["packing_work", "packing_seal"]:
		crate.texture = load("res://assets/props/tea_crate_open.png") if model.stage == "packing_work" else load("res://assets/props/tea_crate.png")
		crate.position = Vector2(720, 462)
		crate.size = Vector2(490, 327)
		if not changed:
			player_actor.walk_to(Vector2(635, 790), 0.65)
		var tween := create_tween()
		crate.position.y += 36
		tween.tween_property(crate, "position:y", 462.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif cargo_group.visible: crate.visible = false
	elif model.stage in ["arrival", "acceptance"]:
		crate.position = Vector2(1560, 579)
		crate.size = Vector2(260, 175)
		crate.modulate = Color("a7957c") if model.pending_delivery.get("damaged", false) else Color.WHITE

func _header() -> void:
	_panel(page, Rect2(26, 22, 1868, 84), DARK)
	_label(page, "十三行  /  茶船将发", Rect2(52, 30, 400, 62), 33, GOLD, true)
	_money_icon(page, Rect2(475, 46, 32, 32))
	_label(page, "现钱  %d" % model.cash if model.cash >= 0 else "缺口  %d" % -int(model.cash), Rect2(516, 34, 223, 56), 29)
	var overdue: bool = not model.contract.is_empty() and model.ticks > model.contract.deadline
	_label(page, _delivery_time_text(), Rect2(750, 34, 315, 56), 29, Color("f0a278") if overdue else PAPER).name = "DeliveryTime"
	if model.debt_due() > 0:
		_label(page, "待还 %d" % model.debt_due(), Rect2(1080, 34, 175, 56), 25, GOLD)
	_button(page, "ledger", "账本", Rect2(1270, 29, 130, 68), _show_ledger)
	_button(page, "help", "帮助", Rect2(1415, 29, 130, 68), _show_help)
	_button(page, "sound", "声音设置", Rect2(1560, 29, 160, 68), _show_audio_settings)
	_button(page, "exit", "结束", Rect2(1735, 29, 132, 68), _show_exit)
	var place_name: String = {"counter":"行号 · 账房", "market":"茶市 · 梁记茶庄", "inspection":"茶庄 · 验茶台", "roasting":"货栈 · 焙茶间", "packing":"货栈 · 装箱间", "dock":"江岸 · 驳运码头", "vessel":"珠江 · 货艇上"}[current_location]
	_panel(page, Rect2(40, 134, 420, 94), DARK)
	_label(page, place_name, Rect2(60, 140, 382, 44), 29, GOLD, true)
	var weather_text: String = "出门时：" + model.weather_name()
	if model.stage == "voyage":
		weather_text = {"squall":"江上突遇风雨", "leak":"舱底渗水，等待处置", "clear":"这一程水路尚平稳"}[model.cargo_event]
	_label(page, weather_text, Rect2(60, 188, 380, 30), 21, MUTED)
	var chapter: int = model.chapter()
	_panel(page, Rect2(540, 136, 840, 66), DARK)
	for i in 5:
		_label(page, ("● " if i <= chapter else "○ ") + ["接单", "备茶", "封箱", "驳运", "交账"][i], Rect2(562 + i * 163, 145, 160, 47), 25, GOLD if i == chapter else MUTED)
	_button(page, "journey", "这一趟的经历", Rect2(43, 249, 250, 63), _show_journey)
	if not model.contract.is_empty():
		_panel(page, Rect2(1482, 133, 400, 147), DARK)
		_label(page, model.contract.name + " · 十箱茶", Rect2(1503, 147, 355, 38), 27, GOLD)
		_label(page, "货色要求 %d  ·  单价 %d" % [model.contract.quality, model.contract.price], Rect2(1503, 193, 355, 34), 23)
		_label(page, model.quality_report, Rect2(1503, 237, 355, 30), 23, MUTED)
	idle_hint = _label(page, "轻触下方选项，让这笔生意继续。", Rect2(630, 745, 680, 40), 25, GOLD)
	idle_hint.visible = false

func _money_icon(parent: Node, box: Rect2) -> void:
	var icon := MoneyIcon.new()
	icon.position = box.position
	icon.size = box.size
	parent.add_child(icon)

func _delivery_time_text() -> String:
	if model.contract.is_empty(): return "等待接单"
	var remaining: int = int(model.contract.deadline) - int(model.ticks)
	if not model.result.is_empty():
		return "交货逾期 %d 天" % -remaining if remaining < 0 else "交货用时 %d 天" % model.ticks
	if remaining < 0: return "已逾期 %d 天" % -remaining
	if remaining == 0: return "今日须交货"
	return "距交货还剩 %d 天" % remaining

func _render_attract() -> void:
	_button(page, "sound", "声音设置", Rect2(1650, 40, 220, 72), _show_audio_settings)
	_panel(page, Rect2(95, 144, 815, 775), Color(0.06, 0.13, 0.095, 0.86), Color("9b885f"))
	_label(page, "广 州 十 三 行", Rect2(150, 185, 650, 70), 35, GOLD)
	_label(page, "茶船将发", Rect2(144, 285, 720, 140), 102, PAPER, true)
	_label(page, "一笔茶单，一段由你作主的生意。", Rect2(154, 450, 700, 58), 32)
	_label(page, "入茶市 · 辨货色 · 亲手封箱 · 驳运交货", Rect2(154, 550, 700, 66), 28, GOLD)
	_label(page, "价钱会变，风雨难料。\n这一次，你能把茶货和本钱一起带回来吗？", Rect2(154, 635, 687, 100), 28)
	_button(page, "start", "接过账本，开张", Rect2(153, 776, 640, 100), _start, true)
	_label(page, "你的化身 · " + str(avatar_profile.display_name), Rect2(1120, 904, 620, 60), 34, PAPER, true)
	_button(page, "avatar", "阿砚 / 阿宁 · 切换角色", Rect2(1150, 978, 500, 73), _show_character_picker)
	_label(page, "v%s 单机茶叶篇  /  鼠标或触摸  /  剧情人物与数值为游戏设定" % app_version, Rect2(105, 980, 980, 40), 23, PAPER)

func _story() -> Array:
	var name := str(avatar_profile.display_name)
	if action_busy: return ["梁老板" if model.stage == "inspection_work" else "陈叔", workshop_performance.dialogue()]
	match model.stage:
		"intro": return ["陈叔 · 行号老管事", name + "，黄埔的商船就要启航了。外商托行号采办十箱茶，这回让你独当一面。"]
		"contract": return ["陈叔", model.last_line + " 三种茶单，交期和货色要求各不相同。"]
		"market": return ["梁老板 · 茶商", MarketStory.welcome(model)]
		"bargain": return ["梁老板", MarketStory.before_offer(model)]
		"bargain_chat": return [name, "梁老板，先不急着定价。我想问清这批货，再掂量怎么成交。"]
		"bargain_result":
			var reply: Array = MarketStory.reply(model)
			return [name if reply[0] == "player" else "梁老板", reply[1]]
		"inspection": return ["梁老板", MarketStory.inspection_open(model)]
		"inspection_work": return ["梁老板", model.last_line]
		"roast_plan": return ["陈叔", model.last_line]
		"roasting_work": return ["陈叔", model.last_line]
		"remedy":
			var just_inspected: bool = not model.events.is_empty() and model.events[-1].label in ["未验货", "抽样结果", "复核结果"]
			if not model.events.is_empty() and model.events[-1].label == "复焙收茶":
				return ["陈叔", QualityDisplay.roast_response(model)]
			return [name, MarketStory.inspection_response(model) if just_inspected else model.last_line]
		"shipment_review": return ["陈叔", "这批货仍有不达标风险。可以回去处理；也可以装运，到货后再决定是否接受折价。"]
		"packing": return ["陈叔", ("外头云低，箱里的防潮不能轻看。" if model.weather > 0 else "天晴也得防舱底潮气。") + " 选好包装，我们一起封箱。"]
		"packing_work": return ["陈叔", ["先取下方衬料，再点箱口铺进去。隔开箱壁，少一分潮气。", "取来茶货，再点箱口装入。码放平整，路上才少些晃动。", "取来箱盖和绳，再点箱口封好。这十箱茶，就要交给船家了。"][model.packing_step]]
		"packing_seal": return ["陈叔", model.last_line]
		"dock":
			if model.bargain_result.get("delay", 0) > 0:
				return ["阿顺 · 船家", "茶市多等了%d天？%s。快船、合运还是沿岸走，你得把后面的风浪也算上。" % [model.bargain_result.delay, _delivery_time_text()]]
			return ["阿顺 · 船家", "%s已经备好。%s" % [model.packaging.name, _delivery_time_text() + "，路线得细算。" if model.ticks >= model.contract.deadline - 3 else "走得快、走得稳，价钱和风险各不相同。"]]
		"voyage": return ["阿顺", model.last_line]
		"voyage_report": return ["阿顺", model.last_line + " 靠岸后，交接人还要复核货色和船期。"]
		"acceptance": return ["怀特 · 商船交接人", model.last_line]
		"arrival":
			var r: Dictionary = model.result
			return ["怀特 · 商船交接人", "%s。到货%d箱，达到原单货色的%d箱；这笔交接记清了。" % [_fulfillment_text(), r.delivered, r.qualified]]
	return ["陈叔", "做生意，得把每一步都照应好。"]

func _choices() -> Array:
	var options: Array = []
	match model.stage:
		"intro": return [["我来试试", "接过账本，查看订单"], ["请陈叔指点", "先听一句生意经"]]
		"contract":
			for c in model.data.contracts:
				options.append([c.name + " · 逾期每天扣%d" % c.penalty, "单价%d · %d天内交货 · 货色≥%d" % [c.price, c.deadline, c.quality]])
		"market":
			for i in 3:
				var s: Dictionary = model.data.suppliers[i]
				options.append([s.name + " · 花费%d" % model.quotes[i], "取货%d天 · %s" % [s.ticks, s.description]])
		"bargain":
			var quote := int(model.supplier.quote)
			return [["照这个价，早些取货", "照价成交 · 不额外耗时"],
				["十箱一起收，匀我一点", "谈成可省 %d" % int(round(quote * 0.08))],
				["这口价，还得再让些", "谈成可省 %d" % int(round(quote * 0.18))]]
		"bargain_chat": return [["这批货从哪里来？", "问货源 · 了解品质起伏"], ["赶得上我的船期吗？", "问交期 · 算取货与还价时间"], ["茶样能代表整批吗？", "问货色 · 了解验货的作用"]]
		"bargain_result":
			return [["接过货单", "十箱货 · 把价钱和用时记清"]] if model.bargain_beat == 0 else [["请带路，去验茶", "前往验茶台 · 再定验货深度"]]
		"inspection": return [["凭样收货", "花费0 · 耗时0天 · 货色未知"], ["抽样开箱", "花费8 · 耗时1天 · 货色区间"], ["逐箱复核", "花费18 · 耗时2天 · 准确货色"]]
		"remedy": return [["准备装运", "不加支出 · 先检查货色风险"], ["%s · 花费20起 · 1—3天" % ("再次复焙" if model.rework_count > 0 else "复焙整理"), "常火：" + model.remedy_preview(12)], ["补价换货 · 花费34 · 2天", model.remedy_preview(24)]]
		"roast_plan":
			for p in model.ROAST_PLANS:
				options.append(["%s · 花费%d · %d天" % [p.name, p.cost, p.ticks], model.remedy_preview(int(p.gain))])
		"inspection_work", "roasting_work": return []
		"shipment_review": return [["回去再处理", "不花钱 · 不重抽货色"], ["带风险装运", "未达标时另谈价 · 可能亏本"]]
		"packing":
			for p in model.data.packing:
				options.append([p.name + " · 花费%d" % p.cost, "耗时%d天 · %s" % [p.ticks, p.description]])
		"packing_work": return []
		"packing_seal": return [["请阿顺点货装船", "十箱已封妥 · 前往驳运码头"]]
		"dock":
			for r in model.data.routes:
				options.append([r.name + " · 花费%d" % r.cost, "耗时%d天 · %s" % [r.ticks, r.description]])
		"voyage":
			var titles: Array
			var detail: Array
			if model.cargo_event == "squall":
				titles = ["靠岸避风", "抢在船期前赶路", "临时加篷"]
				detail = ["花费0 · 多用2天", "花费0 · 不加时", "花费12 · 多用1天"]
			elif model.cargo_event == "leak":
				titles = ["停船补漏", "加紧舀水，继续赶路"]
				detail = ["花费12 · 多用1天", "花费0 · 不加时"]
			else:
				titles = ["雇帮手过驳", "照常交接"]
				detail = ["花费8 · 节省1天", "花费0 · 不加时"]
			for i in titles.size():
				options.append([titles[i], "%s · 损货约%d%%" % [detail[i], roundi(model.risk(i) * 100)]])
		"arrival": return [["回行号结账", "看看这笔生意的实际盈亏"]]
		"voyage_report": return [["靠岸交验", "点清茶箱，与商船交接人会面"]]
		"acceptance":
			var d: Dictionary = model.pending_delivery
			return [["接受折价 · 原单未达标", "货款%d（已扣迟交%d）" % [d.due, d.penalty]], ["取消原单，转售止损", "卖得%d · 另付15改单费" % d.resale_gross]]
	return options

func _render_story() -> void:
	var words: Array = _story()
	_panel(page, Rect2(40, 800, 1840, 112), DARK, Color("a58e64"))
	_label(page, str(words[0]), Rect2(64, 811, 305, 80), 27, GOLD, true)
	dialogue_label = _label(page, str(words[1]), Rect2(382, 810, 1355, 86), 30)
	dialogue_label.visible_characters = -1 if test_mode or action_busy else 0
	_button(page, "reveal", "全文", Rect2(1750, 822, 100, 65), func(): dialogue_clock = 1000)
	var options := _choices()
	var count := options.size()
	if count > 0:
		var width := minf(594, (1840.0 - (count - 1) * 22) / count)
		var start := (1920 - (width * count + (count - 1) * 22)) / 2.0
		for i in count:
			var value: String = str(options[i][0]) + "\n" + str(options[i][1])
			var enabled: bool = model.available(i)
			if not enabled: value = str(options[i][0]) + "\n" + model.unavailable_reason(i)
			var expected: String = model.stage
			var button: Button = _button(page, "choice_%d" % i, value, Rect2(start + i * (width + 22), 931, width, 115),
				_choose.bind(i, expected, model.revision), count == 1, not enabled)
			if model.stage == "bargain" and i > 0 and enabled:
				var line_width := font_body.get_string_size(str(options[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
				_money_icon(button, Rect2((width - line_width) * 0.5 - 33, 64, 27, 27))
	if model.stage in ["packing_work", "roasting_work"]:
		_render_workbench()
	elif model.stage in ["market", "bargain", "bargain_chat", "bargain_result"]:
		_render_market_counter()
	elif model.stage == "inspection_work":
		_render_inspection()
	elif model.stage == "roast_plan":
		_panel(page, Rect2(643, 244, 650, 120), DARK, GOLD)
		_label(page, "这一焙，先定火候", Rect2(677, 258, 594, 49), 36, GOLD, true)
		_label(page, "选定后记账；操作不比手速，也不额外扣钱。", Rect2(677, 311, 594, 42), 23)
		_button(page, "roast_back", "先不加工，回去算一算", Rect2(740, 697, 450, 78), _station_action.bind("cancel_roast", model.revision))
	elif model.stage == "inspection":
		_panel(page, Rect2(650, 280, 655, 99), DARK)
		_label(page, "茶样已开 · 请选择验货深度", Rect2(682, 292, 602, 73), 33, GOLD, true)
	elif model.stage == "packing_seal":
		_panel(page, Rect2(666, 289, 587, 106), DARK, GOLD)
		_label(page, "十箱封妥 · 准备装船", Rect2(699, 303, 530, 79), 39, GOLD, true)
	elif model.stage == "voyage":
		_panel(page, Rect2(671, 306, 579, 123), DARK, GOLD)
		_label(page, {"squall":"江上突遇风雨", "leak":"舱底发现渗水", "clear":"顺水抵达交接处"}[model.cargo_event], Rect2(709, 320, 520, 94), 41, GOLD, true)
	elif model.stage == "voyage_report":
		var d: Dictionary = model.pending_delivery
		_panel(page, Rect2(637, 262, 665, 174), DARK, GOLD)
		_label(page, "损货%d箱 · 余下%d箱" % [d.lost, d.delivered] if d.damaged else "十箱茶 · 平安靠岸", Rect2(670, 278, 605, 65), 38, GOLD, true)
		_label(page, "到货货色%d · 要求%d\n%s" % [d.quality, model.contract.quality, "原单货色未达标，靠岸后需要议价。" if not d.quality_met else "货色达到门槛，还要核对数量与交期。"], Rect2(670, 348, 605, 75), 25)
	elif model.stage in ["remedy", "shipment_review"]:
		_render_quality_result()
	elif model.stage == "acceptance":
		_panel(page, Rect2(670, 328, 590, 205), DARK, GOLD)
		_label(page, "原单货色未达标", Rect2(699, 342, 535, 60), 39, GOLD, true)
		_label(page, "要求%d · 到货%d\n请决定折价成交，或转售止损。" % [model.contract.quality, model.pending_delivery.quality], Rect2(699, 414, 535, 90), 29)
	else:
		_button(page, "look", "◎  留意场景", Rect2(790, 666, 350, 77), _show_history)
	_label(page, "确认行动才推进天数，阅读思考不计时。", Rect2(61, 752, 575, 31), 21, PAPER)
	if model.can_borrow() or model.stage in ["packing", "dock"]:
		_button(page, "support", "资金不足？找陈叔" if model.cash < 20 else "陈叔 · 周转与赊账", Rect2(42, 649, 397, 87), _show_support, model.cash < 20, action_busy)

func _render_quality_result() -> void:
	var panel := _panel(page, Rect2(636, 279, 674, 342), DARK, GOLD)
	panel.name = "QualityResult"
	_label(panel, "装运前核对" if model.stage == "shipment_review" else ("验茶结果" if model.last_treatment.is_empty() else "处理结果"), Rect2(30, 13, 614, 39), 26, PAPER, true)
	var value := _label(panel, QualityDisplay.headline(model), Rect2(30, 59, 614, 66), 42, GOLD)
	value.name = "QualityValue"
	_label(panel, "订单要求 ≥ %d" % model.contract.quality, Rect2(30, 132, 614, 39), 28, PAPER).name = "QualityRequirement"
	_label(panel, model.quality_guidance(), Rect2(30, 184, 614, 67), 25, PAPER)
	var comparison: String = QualityDisplay.comparison(model)
	_label(panel, comparison if comparison != "" else "抽样给出范围；逐箱复核才能确认准确货色。", Rect2(30, 263, 614, 35), 23, GOLD if comparison != "" else MUTED).name = "QualityComparison"
	_label(panel, "复焙 %d/2次 · 换货 %d/1次 · 处理要花钱与时间" % [model.rework_count, int(model.exchange_used)], Rect2(30, 304, 614, 29), 21, MUTED)

func _render_inspection() -> void:
	var done: int = model.inspection_marks.size()
	var required: int = model.inspection_level + 1
	_panel(page, Rect2(648, 244, 638, 114), DARK, GOLD)
	_label(page, "抽样观察 · 任选两项" if required == 2 else "逐箱复核 · 查看三项", Rect2(678, 252, 583, 47), 33, GOLD, true)
	var progress := ""
	for i in 3: progress += ("● " if i in model.inspection_marks else "○ ") + ["叶形", "干湿", "汤色"][i] + "    "
	_label(page, progress, Rect2(678, 306, 583, 39), 25)
	if action_busy:
		_rect(page, Rect2(676, 365, 580, 5), Color("50604b"))
		work_progress = _rect(page, Rect2(676, 365, 1, 5), GOLD)
	for i in 3:
		var seen: bool = i in model.inspection_marks
		_button(page, "observe_%d" % i, ("✓ " if seen else "◎ ") + ["看叶形", "辨干湿", "看汤色"][i], Rect2(601 + i * 290, 664, 225, 83), _choose.bind(i, "inspection_work", model.revision), not seen, seen or action_busy)
	_button(page, "inspection_done", workshop_performance.caption() + " · 正在观察" if action_busy else ("记下验茶结果" if done >= required else "已查看%d/%d项 · 继续看茶样" % [done, required]), Rect2(650, 940, 620, 105), _station_action.bind("finish_inspection", model.revision), true, done < required or action_busy)

func _render_workbench() -> void:
	var roast: bool = model.stage == "roasting_work"
	var step: int = model.roast_step if roast else model.packing_step
	var tools_list := ["火钳", "竹铲", "回凉竹筛"] if roast else ["衬料", "茶货", "箱盖与绳"]
	var verbs := ["拨匀炭火", "翻茶散湿", "收茶回筛"] if roast else ["铺好衬料", "装入茶货", "合盖扎绳"]
	var selected_tool: bool = model.work_tool == step
	_panel(page, Rect2(655, 242, 637, 98), DARK, GOLD)
	_label(page, "%s · %d / 3" % [model.roast_plan.name if roast else model.packaging.name, step + 1], Rect2(685, 251, 582, 43), 32, GOLD, true)
	_label(page, "正在%s，稍候看结果" % workshop_performance.caption() if action_busy else ("已取%s → 点场景中的操作点" % tools_list[step] if selected_tool else "先取下方%s，再点场景操作" % tools_list[step]), Rect2(685, 295, 582, 34), 23)
	_button(page, "work_action" if roast else "pack_action", "正在" + workshop_performance.caption() if action_busy else (verbs[step] if selected_tool else "先取" + tools_list[step]), Rect2(742, 689, 429, 83), _choose.bind(0, model.stage, model.revision), true, not selected_tool or action_busy)
	if action_busy:
		_rect(page, Rect2(681, 351, 580, 5), Color("50604b"))
		work_progress = _rect(page, Rect2(681, 351, 1, 5), GOLD)
	for i in 3:
		var state := "已完成" if i < step else ("已取用" if i == step and selected_tool else ("轻触取用" if i == step else "稍后使用"))
		var b: Button = _button(page, "tool_%d" % i, "%s\n%s" % [tools_list[i], state], Rect2(350 + i * 412, 934, 390, 111), _take_tool.bind(i, model.revision), i == step, i != step or selected_tool or action_busy)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var icon := TextureRect.new()
		icon.texture = _tool_texture(i, roast)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		icon.position = Vector2(15, 8)
		icon.size = Vector2(116, 95)
		icon.modulate.a = 1.0 if i == step else 0.45

func _tool_texture(index: int, roast: bool) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/props/workshop_tools.png")
	var cell := atlas.atlas.get_size() / Vector2(3, 2)
	atlas.region = Rect2(Vector2(index * cell.x, 0 if roast else cell.y), cell)
	atlas.filter_clip = true
	return atlas

func _take_tool(index: int, ticket: int) -> void:
	if action_busy or overlay_kind != "" or (transition_guard > 0 and not test_mode): return
	if not model.select_tool(index, ticket): return
	_play_click()
	idle_seconds = 0
	_render()
	if tool_motion: tool_motion.kill()
	tool_sprite.texture = _tool_texture(index, model.stage == "roasting_work")
	tool_sprite.visible = true
	tool_sprite.modulate = Color.WHITE
	tool_sprite.scale = Vector2.ONE * 0.30
	tool_sprite.position = Vector2(408 + index * 412, 985)
	tool_sprite.rotation = 0
	tool_motion = create_tween()
	tool_motion.tween_property(tool_sprite, "position", Vector2(1090, 584), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tool_motion.parallel().tween_property(tool_sprite, "rotation", -0.25, 0.42)
	workshop_effect.play_at(Vector2(955, 650))
	transition_guard = 0.45

func _station_action(action: String, ticket: int) -> void:
	if action_busy or overlay_kind != "" or (transition_guard > 0 and not test_mode): return
	var changed: bool = model.finish_inspection(ticket) if action == "finish_inspection" else model.cancel_roast_plan(ticket)
	if not changed: return
	_play_click()
	idle_seconds = 0
	_render()
	transition_guard = 0.4

func _fulfillment_text() -> String:
	var r: Dictionary = model.result
	if r.mode == "resale": return "原单取消 · 已转售止损"
	if r.mode == "discount": return "原单未达标 · 已折价成交"
	if r.contract_met: return "原单达标 · 如约交付"
	return "原单未达标 · " + ("数量不足" if r.delivered < 10 else "迟交")

func _render_market_counter() -> void:
	var receipt := _panel(page, Rect2(704, 287, 508, 255), PAPER, GOLD)
	if model.stage == "market":
		_label(receipt, "梁记茶庄 · 今日有茶", Rect2(30, 14, 448, 60), 33, INK, true)
		_label(receipt, "十箱茶，三处货源", Rect2(30, 87, 448, 60), 36, INK)
		_label(receipt, "取货越快，本钱未必越少。\n先挑货，再同梁老板谈价。", Rect2(30, 162, 448, 73), 25, INK)
		return
	if model.stage == "bargain_result":
		var r: Dictionary = model.bargain_result
		_label(receipt, "成交货单 · 十箱茶", Rect2(30, 12, 448, 51), 32, INK, true)
		_label(receipt, "实付 %d" % r.paid, Rect2(30, 71, 448, 69), 47, INK)
		_label(receipt, "让利 %d  ·  还价多耗 %d天" % [r.saving, r.delay], Rect2(30, 147, 448, 40), 24, INK)
		_label(receipt, "取货另耗%d天 · 茶货尚未验明" % r.pickup_ticks, Rect2(30, 196, 448, 40), 24, INK)
	else:
		_label(receipt, str(model.supplier.name) + " · 十箱", Rect2(30, 12, 448, 51), 32, INK, true)
		_label(receipt, "报价 %d" % model.supplier.quote, Rect2(30, 71, 448, 69), 47, INK)
		_label(receipt, "取货 %d天  ·  货色待验" % model.supplier.ticks, Rect2(30, 149, 448, 40), 25, INK)
		_label(receipt, "谈价前，先把想问的问清。", Rect2(30, 198, 448, 37), 23, INK)
		_button(page, "market_talk", "先问一句 · 不耗天数" if model.stage == "bargain" else "回到议价", Rect2(757, 704, 406, 72), _market_conversation.bind(model.stage == "bargain", model.revision))

func _market_conversation(open: bool, revision: int) -> void:
	if overlay_kind != "" or (transition_guard > 0 and not test_mode): return
	if model.market_conversation(open, revision):
		idle_seconds = 0
		_render()
		transition_guard = 0.25

func _render_result() -> void:
	var r: Dictionary = model.result
	var card := _panel(page, Rect2(635, 179, 686, 587), PAPER, GOLD)
	_label(card, _fulfillment_text(), Rect2(40, 24, 610, 67), 32, INK if r.contract_met else RUST, true)
	_label(card, "收支持平" if r.profit == 0 else (("赚了 %d" % r.profit) if r.profit > 0 else ("亏了 %d" % -int(r.profit))), Rect2(40, 95, 600, 87), 63, INK if r.profit >= 0 else RUST, true)
	var rows := [
		["货物验收", "到货%d箱 · 达标%d箱" % [r.delivered, r.qualified]],
		["转售货值" if r.mode == "resale" else "交货货值", "%d" % r.gross],
		["改单费用" if r.mode == "resale" else "迟交扣款", "−%d" % (r.cancellation_fee if r.mode == "resale" else r.penalty)],
		["实际货款", "%d" % r.due],
		["借赊清算", "%d（明细见账本）" % r.debt_settlement],
		["全部支出", "−%d" % r.cost],
		["剩余现钱" if r.final_cash >= 0 else "清算缺口", "%d" % absi(int(r.final_cash))]]
	for i in rows.size():
		_label(card, rows[i][0], Rect2(42, 200 + i * 49, 206, 43), 27, INK)
		_label(card, rows[i][1], Rect2(248, 200 + i * 49, 408, 43), 25, INK)
	_panel(page, Rect2(40, 800, 1840, 112), DARK, GOLD)
	var line := "这单有进账。下次换一条路、换一种货，运气也未必相同。"
	if r.profit < 0:
		line = "这一趟蚀了本。先看看货色、损货与交期，账上的教训，能带去下一单。"
	elif not r.contract_met:
		line = "这单虽然赚了钱，原单仍未达标。下次再把货色、数量与交期一起照应好。"
	if r.funding_gap > 0:
		line = "这趟亏掉了本金，清算还差%d。缺口没有免除，账本会记下这次经营的代价。" % r.funding_gap
	_label(page, "陈叔", Rect2(68, 812, 285, 84), 29, GOLD, true)
	_label(page, line, Rect2(380, 812, 1400, 84), 30)
	_button(page, "review", "翻开详细账本", Rect2(336, 934, 588, 112), _show_ledger)
	_button(page, "choice_0", "听听陈叔的收尾", Rect2(946, 934, 588, 112), _choose.bind(0, "result", model.revision), true)

func _render_epilogue() -> void:
	var ending: Array = model.ending()
	_panel(page, Rect2(586, 240, 795, 485), DARK, GOLD)
	_label(page, ending[0], Rect2(631, 269, 705, 80), 44, GOLD, true)
	_label(page, ending[1], Rect2(631, 379, 705, 144), 31)
	_label(page, ending[2], Rect2(631, 540, 705, 117), 28, GOLD)
	_panel(page, Rect2(40, 800, 1840, 112), DARK, GOLD)
	_label(page, str(avatar_profile.display_name), Rect2(66, 813, 285, 82), 29, GOLD)
	_label(page, MarketStory.ending_echo(model), Rect2(382, 813, 1320, 82), 30)
	_button(page, "again", "再做一单 · 新行情", Rect2(335, 934, 592, 112), func(): _end_session("replay"); _start())
	_button(page, "finish", "合上账本，完成体验", Rect2(950, 934, 640, 112), func(): _end_session("completed"), true)
	_label(page, "知识依据：香港艺术馆「外销艺术」藏品说明；人物、场景、故事与数值为艺术化设定。", Rect2(405, 745, 1160, 37), 20, PAPER)

func _start() -> void:
	if overlay_kind != "" or (transition_guard > 0 and not test_mode): return
	if model.start():
		idle_seconds = 0
		session_seconds = 0
		logger.record("start", model.session_id, {"version":app_version, "character":avatar_profile.get("id", "custom")})
		_render()
		transition_guard = 0.4

func _choose(index: int, expected: String, expected_revision: int = -1) -> void:
	if action_busy or overlay_kind != "" or model.stage != expected or (transition_guard > 0 and not test_mode): return
	if not test_mode and expected in ["inspection_work", "roasting_work"]:
		if expected_revision >= 0 and model.revision != expected_revision: return
		if not model.available(index): return
		_begin_work_performance(index, expected)
		return
	_apply_choice(index, expected, expected_revision)

func _begin_work_performance(index: int, stage: String) -> void:
	pending_work = {"index":index, "stage":stage, "revision":model.revision}
	action_busy = true
	if tool_motion: tool_motion.kill()
	workshop_performance.begin(stage, index if stage == "inspection_work" else int(model.roast_step))
	_render()
	player_actor.walk_to(Vector2(485, 790), 0.32)
	npc_actor.walk_to(Vector2(1450, 790), 0.32)
	player_actor.react("inspect" if stage == "inspection_work" else "work", workshop_performance.duration)
	npc_actor.react("agree", workshop_performance.duration)
	idle_seconds = 0
	_play_click()

func _finish_work_performance() -> void:
	if not action_busy or pending_work.is_empty(): return
	var pending := pending_work.duplicate()
	pending_work.clear()
	action_busy = false
	tool_sprite.visible = false
	_apply_choice(int(pending.index), str(pending.stage), int(pending.revision), true)

func _apply_choice(index: int, expected: String, expected_revision: int, performed: bool = false) -> void:
	var old_cash: int = model.cash
	if model.choose(index, expected, expected_revision):
		_play_click()
		logger.record("choice", model.session_id, {"stage":expected, "choice":index, "cash_change":model.cash - old_cash, "ticks":model.ticks})
		idle_seconds = 0
		_render()
		if expected == "bargain" or (expected == "bargain_result" and model.stage == "bargain_result"):
			var receiving: bool = expected == "bargain_result"
			market_exchange.play_exchange(int(model.bargain_result.paid), receiving)
			player_actor.react("receive" if receiving else "agree")
			npc_actor.react("refuse" if model.bargain_result.delay > 0 and not receiving else "agree")
			player_actor.walk_to(Vector2(580 if receiving else 510, 790), 0.5)
			npc_actor.walk_to(Vector2(1390 if model.bargain_result.delay > 0 else 1315, 790), 0.5)
			transition_guard = 1.25
		elif expected == "bargain_chat":
			npc_actor.react("agree")
		if expected == "inspection_work": workshop_effect.play_at(Vector2(680 + index * 310, 545))
		if not performed and expected in ["packing_work", "roasting_work"] and model.stage == expected:
			if tool_motion: tool_motion.kill()
			tool_motion = create_tween()
			tool_motion.tween_property(tool_sprite, "position", Vector2(939, 550), 0.26).set_trans(Tween.TRANS_SINE)
			tool_motion.parallel().tween_property(tool_sprite, "rotation", 0.25, 0.26)
			tool_motion.tween_property(tool_sprite, "modulate:a", 0.0, 0.3)
			tool_motion.tween_callback(func(): tool_sprite.visible = false)
		transition_guard = maxf(transition_guard, 0.2 if performed else (0.8 if expected in ["packing_work", "roasting_work"] else 0.4))

func _play_click() -> void:
	if not ambient_enabled: return
	var samples := PackedByteArray()
	samples.resize(4410 * 2)
	for i in 4410:
		var sample := int(sin(float(i) / 22050.0 * TAU * 640) * exp(-float(i) / 700.0) * 3000)
		samples.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = samples
	sound_player.stream = wav
	sound_player.play()

func _end_session(reason: String) -> void:
	workshop_performance.cancel()
	pending_work.clear()
	action_busy = false
	player_actor.performance_paused = false
	npc_actor.performance_paused = false
	logger.record("end", model.session_id, {"reason":reason, "duration_seconds":roundi(session_seconds), "result":model.result})
	_close_overlay()
	model.reset()
	if reason != "replay":
		avatar_profile = default_avatar_profile.duplicate(true)
		player_actor.set_profile(avatar_profile)
	primary_touch = -1
	idle_seconds = 0
	session_seconds = 0
	transition_guard = 0
	_render()

func _modal(title: String, body: String, kind: String, body_font_size: int = 28) -> Control:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_rect(overlay, Rect2(0, 0, 1920, 1080), Color(0.02, 0.06, 0.04, 0.75))
	var panel := _panel(overlay, Rect2(380, 170, 1160, 745), PAPER, GOLD)
	_label(panel, title, Rect2(48, 25, 1065, 85), 43, INK, true)
	_label(panel, body, Rect2(49, 130, 1062, 458), body_font_size, INK)
	overlay_kind = kind
	workshop_performance.paused = true
	_button(panel, "close_help", "回到场景", Rect2(50, 627, 1060, 85), _close_overlay, true)
	return panel

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null
	overlay_kind = ""
	primary_touch = -1
	idle_seconds = 0

func _show_help() -> void:
	_modal("陈叔的生意经", "金额与天数为游戏设定，贸易流程经过压缩。\n货色为0—100分；货色、数量、交期都满足，原单才算达标。\n\n阅读与思考不耗天数，确认经营行动才推进时间。\n验茶：抽样查看两项，复核查看三项，再确认验茶结果。\n复焙：先选火候，再取工具操作，最多两次。\n装箱：依次取衬料、茶货、箱盖与绳，再点箱口。\n\n现钱不足可借款一次，或赊箱、赊运，最后还账。\n货色不足可再处理；带风险装运，到货后另谈价格。\n\n单机停留不清空。F11切换全屏；Esc打开结束菜单。", "help", 25)

func _show_audio_settings() -> void:
	var panel := _modal("声音设置", "", "audio")
	music_title_label = _label(panel, "", Rect2(50, 135, 1060, 65), 31, INK)
	_update_music_title(music_player.current_title())
	_label(panel, "Main Theme → 13 Hongs → 循环\n进入游戏、切换场景和再做一单时，音乐会接着播放。", Rect2(50, 218, 1060, 95), 26, INK)
	_button(panel, "music_toggle", "背景音乐 开" if music_player.enabled else "背景音乐 关", Rect2(50, 341, 510, 84), _toggle_music, true)
	_button(panel, "effects_toggle", "点击音效 开" if ambient_enabled else "点击音效 关", Rect2(584, 341, 526, 84), _toggle_effects)
	_label(panel, "音乐音量", Rect2(50, 470, 210, 60), 28, INK)
	var slider := HSlider.new()
	slider.name = "MusicVolume"
	panel.add_child(slider)
	slider.position = Vector2(270, 470)
	slider.size = Vector2(840, 60)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = music_player.volume_percent
	slider.accessibility_name = "背景音乐音量"
	slider.value_changed.connect(music_player.set_volume_percent)
	# The game uses native touch events, with mouse emulation disabled.
	slider.gui_input.connect(func(event: InputEvent):
		if (event is InputEventScreenTouch and event.pressed) or event is InputEventScreenDrag:
			var inset := slider.get_theme_icon("grabber").get_width() * 0.5
			slider.value = clampf((event.position.x - inset) / (slider.size.x - inset * 2), 0, 1) * 100
			slider.accept_event()
	)
	_label(panel, "关闭音乐会暂停，重新开启会从刚才的位置继续。", Rect2(50, 547, 1060, 53), 24, INK)

func _update_music_title(title: String) -> void:
	if overlay_kind == "audio" and is_instance_valid(music_title_label):
		music_title_label.text = "正在播放：" + title if music_player.enabled else "已暂停：" + title

func _toggle_music() -> void:
	if overlay_kind != "audio": return
	music_player.set_enabled(not music_player.enabled)
	ui_buttons.music_toggle.text = "背景音乐 开" if music_player.enabled else "背景音乐 关"
	_update_music_title(music_player.current_title())
	if compatibility_mode: logger.record("music", model.session_id, {"enabled":music_player.enabled, "paused":music_player.stream_paused, "volume":music_player.volume_linear})

func _toggle_effects() -> void:
	if overlay_kind != "audio": return
	ambient_enabled = not ambient_enabled
	ui_buttons.effects_toggle.text = "点击音效 开" if ambient_enabled else "点击音效 关"

func _show_journey() -> void:
	var text := "开张：" + str(model.approach) + "。\n\n"
	var start_index := maxi(0, model.events.size() - 6)
	if model.events.is_empty(): text += "陈叔交来账本，第一笔独立照应的茶单正在等你。"
	for i in range(start_index, model.events.size()):
		var event: Dictionary = model.events[i]
		text += "• %s：%s\n" % [event.label, str(event.detail).left(54)]
	_modal("这一趟 · 已发生的事", text.strip_edges(), "journey", 23)

func _show_support() -> void:
	if action_busy: return
	if not model.can_borrow() and model.stage not in ["packing", "dock"]: return
	var ticket: int = model.revision
	var panel := _modal("陈叔 · 生意遇坎，先想办法", "", "support")
	var text := "现钱%d · 结算待还%d。现钱用完不会立即结束生意。\n\n" % [model.cash, model.debt_due()]
	text += "周转：现在借60，结算还66，每局一次。\n"
	if model.stage == "packing": text += "赊用旧箱：现在付0，结算扣12，耗2天，防潮较弱。\n"
	elif model.stage == "dock": text += "候船赊运：现在付0，结算扣18，耗3天，风险较高。\n"
	else: text += "之后若没钱装箱或运船，还能选择赊箱、赊运。\n"
	text += "\n这些钱都要还；最后可能亏本或出现资金缺口。"
	_label(panel, text, Rect2(50, 127, 1060, 315), 27, INK)
	_button(panel, "borrow", "借60 · 结算还66" if model.can_borrow() else "本局周转已使用", Rect2(50, 494, 510, 93), _support_action.bind("borrow", ticket), true, not model.can_borrow())
	if model.stage in ["packing", "dock"]:
		_button(panel, "defer", "赊箱 · 结算付12" if model.stage == "packing" else "赊运 · 结算付18", Rect2(584, 494, 526, 93), _support_action.bind("defer", ticket))

func _support_action(kind: String, ticket: int) -> void:
	if action_busy or overlay_kind != "support": return
	var success: bool = model.borrow(ticket) if kind == "borrow" else model.use_deferred(ticket)
	if not success: return
	logger.record("support", model.session_id, {"kind":kind, "cash":model.cash, "debt_due":model.debt_due()})
	_close_overlay()
	_render()
	transition_guard = maxf(transition_guard, 0.4)

func _show_history() -> void:
	var info: String = {
		"counter":"行号组织贸易\n\n这里的你是行号采购管事，负责采办与交付。行商、采买者和船家各有分工。游戏把这些合作浓缩在一单茶的旅程中。",
		"market":"货色与茶样\n\n样品帮助买卖双方沟通要求。游戏把外观、干燥状况与整批一致性合成「货色」指标，方便理解验货的作用。",
		"packing":"茶箱为什么要衬、要扎？\n\n运输中的潮气、搬动和等待都可能影响货物。这里的三步封箱是互动示意；材料与工序细节仍需馆方资料审定。",
		"dock":"小艇连接货栈与外港\n\n香港艺术馆的外销艺术说明介绍了黄埔停泊的洋船与广州之间的货艇驳运。这里的码头是这条链路的示意，场景并非实测复原。",
		"inspection":"茶样与货色\n\n看叶形、辨干湿、看汤色，是本游戏观察品质的三个入口。准确货色由付费复核给出，抽样仍有范围。画中茶样是示意，不对应真实茶叶评级。",
		"roasting":"复焙与船期\n\n这里把处理方式简化为三种火候。货色评分：常火提升12分，慢火14分，快火8分。费用、时间和提升值是游戏规则，操作动画不是制茶教学。",
		"vessel":"在货艇上\n\n包装、路线和临场应对共同影响损货概率。看到雨并不等于一定损货；同一场风雨，处置与运气都可能改变结局。"}[current_location]
	_modal("停一停，看看身边", info, "history")

func _show_character_picker() -> void:
	if model.stage != "attract" or overlay_kind != "" or (transition_guard > 0 and not test_mode): return
	pending_character_id = str(avatar_profile.get("id", ""))
	# Selection is a preview until confirmed; cancelling never changes the active role.
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_rect(overlay, Rect2(0, 0, 1920, 1080), Color(0.025, 0.065, 0.045, 0.97))
	_label(overlay, "广 州 十 三 行  /  茶船将发", Rect2(125, 39, 900, 45), 25, GOLD)
	_label(overlay, "这一次，你是谁？", Rect2(125, 94, 1200, 84), 58, PAPER, true)
	_label(overlay, "接过陈叔的账本，由你照应第一笔茶单。", Rect2(130, 179, 1300, 46), 28, MUTED)
	_button(overlay, "close_help", "返回", Rect2(1620, 65, 170, 72), _close_overlay)
	overlay_kind = "avatar"
	character_cards.clear()
	character_marks.clear()
	for i in character_profiles.size():
		var profile: Dictionary = character_profiles[i]
		var id := str(profile.id)
		var card = _button(overlay, "character_%d" % i, "", Rect2(360 + i * 620, 252, 580, 607), _select_character.bind(id))
		card.accessibility_name = "选择" + str(profile.display_name)
		var portrait = Actor.new()
		portrait.profile = profile.duplicate(true)
		portrait.profile.height = 475
		portrait.position = Vector2(278, 484)
		card.add_child(portrait)
		_label(card, str(profile.display_name) + (" · 男主角" if i == 0 else " · 女主角"), Rect2(33, 486, 514, 61), 36, PAPER, true)
		_label(card, "行号采购管事 · 初次独立接单", Rect2(33, 547, 514, 41), 25, MUTED)
		character_cards[id] = card
		character_marks[id] = _label(card, "", Rect2(384, 16, 169, 45), 25, GOLD)
	_label(overlay, "两位主角的本钱、订单和机会相同，生意的走向由你的选择决定。", Rect2(360, 874, 1200, 48), 26, MUTED)
	_button(overlay, "confirm_character", "", Rect2(560, 942, 800, 91), _confirm_character, true)
	_select_character(pending_character_id)

func _select_character(id: String) -> void:
	if overlay_kind != "avatar": return
	pending_character_id = id
	var chosen: Dictionary = {}
	for profile in character_profiles:
		var active: bool = profile.id == id
		character_cards[profile.id].add_theme_stylebox_override("normal", _style(Color("263e32") if active else Color("10261b"), GOLD if active else Color("526653")))
		character_marks[profile.id].text = "✓ 已选择" if active else ""
		if active: chosen = profile
	ui_buttons.confirm_character.disabled = chosen.is_empty()
	ui_buttons.confirm_character.text = "请选择一位角色" if chosen.is_empty() else "选用%s，返回开场" % chosen.display_name

func _confirm_character() -> void:
	if overlay_kind != "avatar": return
	var chosen: Dictionary = {}
	for profile in character_profiles:
		if profile.id == pending_character_id: chosen = profile
	if chosen.is_empty(): return
	_close_overlay()
	if not set_player_profile(chosen): return
	logger.record("character", model.session_id, {"id":chosen.id, "stage":model.stage})
	transition_guard = 0

func _show_ledger() -> void:
	var panel := _modal("这笔生意 · 逐项记账", "", "ledger")
	_label(panel, "本金%d · 现钱%d · %s · 已用%d天" % [model.data.initial_cash, model.cash,
		"待补缺口%d" % -int(model.cash) if model.cash < 0 else "待清算%d" % model.debt_due(), model.ticks], Rect2(50, 127, 1060, 55), 27, INK)
	for i in model.ledger.size():
		var row: Dictionary = model.ledger[i]
		var x: int = 50 + floori(float(i) / 7) * 534
		var y: int = 204 + (i % 7) * 44
		_label(panel, row.label, Rect2(x, y, 387, 38), 22, INK)
		_label(panel, "%+d" % row.amount, Rect2(x + 389, y, 113, 38), 23, INK)
	var note := "借款本金不计收入，归还本金也不重复算成本；周转费6才是成本。\n赊账费用在结算时扣除；货款已包含预付，需要抵扣或退款。"
	if not model.result.is_empty():
		var r: Dictionary = model.result
		note = "%s；货款%d − 总成本%d = 利润%d。\n尾款／退款净额：%+d；借赊清算%d；尚待填补缺口%d。" % [_fulfillment_text(), r.due, r.cost, r.profit, r.balance_due, r.debt_settlement, r.funding_gap]
	_label(panel, note, Rect2(50, 532, 1060, 85), 24, INK)

func _show_exit() -> void:
	var panel := _modal("合上账本？", "结束后，这一局的生意将清空。回到开场后可以重新开张。", "exit")
	ui_buttons["close_help"].visible = false
	_button(panel, "cancel_exit", "继续经营", Rect2(50, 627, 512, 85), _close_overlay, true)
	_button(panel, "confirm_exit", "结束本局", Rect2(584, 627, 526, 85), func(): _end_session("active_exit"))

func _show_idle() -> void:
	var panel := _modal("还在照应这笔生意吗？", "轻触继续，回到刚才的场景。\n若已离开，铺头将在15秒内重新开张。", "idle")
	# Opening this prompt must preserve accumulated idle time.
	idle_seconds = float(settings.result_reset_seconds) - 15 if model.stage == "result" else (float(settings.reading_reset_seconds) - 15 if model.stage == "epilogue" else float(settings.prompt_seconds))
	ui_buttons["close_help"].visible = false
	_button(panel, "resume", "我还在，继续", Rect2(50, 627, 1060, 85), _close_overlay, true)

func _tour_tap(id: String, use_touch: bool = true) -> void:
	assert(ui_buttons.has(id) and is_instance_valid(ui_buttons[id]), "Missing UI button " + id)
	var center: Vector2 = ui_buttons[id].get_global_rect().get_center()
	# Test/tour mouse actions represent a deliberate device change, not driver echoes.
	if not use_touch and input_guard.mouse_wait_ms(center) > 0:
		await get_tree().create_timer(input_guard.mouse_wait_ms(center) / 1000.0 + 0.03).timeout
	if use_touch:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = center
		down.pressed = true
		get_viewport().push_input(down, true)
		await get_tree().process_frame
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = center
		up.pressed = false
		get_viewport().push_input(up, true)
	else:
		var down := InputEventMouseButton.new()
		down.position = center
		down.global_position = center
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		get_viewport().push_input(down, true)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.position = center
		up.global_position = center
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().create_timer(0.95).timeout
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://../artifacts/v0.4")
	DirAccess.make_dir_recursive_absolute(directory)
	assert(picture.save_png(directory.path_join(filename + ".png")) == OK)

func _run_ui_tour() -> void:
	var tour = load("res://tests/v4_tour.gd").new()
	await tour.run(self)
