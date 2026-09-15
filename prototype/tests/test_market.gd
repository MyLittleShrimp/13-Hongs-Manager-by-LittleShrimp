extends SceneTree
const Trade = preload("res://scripts/trade_session.gd")
const Story = preload("res://scripts/market_story.gd")
var config: Dictionary
var checks := 0
var app
var examples := {}
var capture_enabled := false

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false, message)

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/trade_v2.json"))
	call_deferred("run")

func at_counter(seed_value: int):
	var t = Trade.new(config)
	t.reset(seed_value)
	t.start()
	for i in [0, 1, seed_value % 3]: verify(t.choose(i), "Reach counter legally")
	return t

func finances(t) -> Array:
	return [t.cash, t.ticks, t.quality, t.rng.state, t.ledger.duplicate(true), t.bargain_result.duplicate(true)]

func layout(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			verify(child.size.x <= box.size.x + 2 and child.size.y <= box.size.y + 2, "Market text fits " + child.name)
			if child is Button:
				for line in child.text.split("\n"):
					var width: float = child.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
					verify(width <= box.size.x - 36, "Market button not clipped: " + line)
		layout(child)

func capture(name: String, wait_seconds: float = 0.95) -> void:
	if not capture_enabled: return
	await create_timer(wait_seconds).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.6")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "GPU market capture")

func run() -> void:
	# Compare with/without all optional dialogue: it cannot secretly change the deal.
	for seed_value in 200:
		for method in 3:
			var baseline = at_counter(seed_value)
			var spoken = at_counter(seed_value)
			var before := finances(spoken)
			for topic in 3:
				verify(spoken.market_conversation(true, spoken.revision), "Open optional dialogue")
				var ticket: int = spoken.revision
				verify(spoken.choose(topic, "bargain_chat", ticket), "Ask a distinct question")
				verify(not spoken.choose(topic, "bargain_chat", ticket), "Stale dialogue callback ignored")
				verify(not Story.before_offer(spoken).is_empty(), "Merchant has a contextual answer")
			verify(finances(spoken) == before, "Questions do not spend, consume time, or reroll tea")
			verify(spoken.market_conversation(true), "Can review asked topics")
			for topic in 3: verify(not spoken.available(topic) and not spoken.choose(topic), "Asked topic is disabled")
			verify(spoken.market_conversation(false), "Return without taking another action")
			verify(baseline.choose(method) and spoken.choose(method), "Complete deal")
			verify(finances(spoken) == finances(baseline), "Dialogue preserves the exact seeded purchase")
			verify(spoken.stage == "bargain_result" and spoken.location() == "market", "Deal stays at counter for exchange")
			verify(spoken.quality_report == "尚未验茶", "Receipt does not reveal hidden batch grade")
			var outcome: String = "%d_%s" % [method, "direct" if method == 0 else ("win" if spoken.bargain_result.success else "loss")]
			if not examples.has(outcome): examples[outcome] = seed_value
			var fixed := finances(spoken)
			verify(not spoken.choose(1), "Only the receipt continuation is valid")
			for beat in 2:
				var ticket: int = spoken.revision
				verify(Story.reply(spoken).size() == 2, "Committed outcome has dialogue")
				verify(spoken.choose(0, "bargain_result", ticket), "Continue exchange")
				verify(not spoken.choose(0, "bargain_result", ticket), "Repeated receipt click cannot advance twice")
			verify(finances(spoken) == fixed and spoken.stage == "inspection", "Exchange books no additional cost or randomness")
			verify(not spoken.market_conversation(true), "Cannot renegotiate after purchase")
			spoken.reset(seed_value)
			verify(spoken.bargain_result.is_empty() and spoken.market_topics.is_empty() and spoken.market_topic == -1 and spoken.bargain_beat == 0, "New trade clears dialogue memory")
	verify(examples.size() == 5, "Both success and failure exist for both negotiation styles")
	var sample = at_counter(1)
	verify(sample.choose(1), "Known deal for information boundary")
	sample.contract.quality = 86
	sample.inspected = 1
	for grade in [82, 90]:
		sample.quality = grade
		verify(Story.inspection_response(sample).contains("不能确定"), "Overlapping sample interval cannot disclose true compliance")
	sample.inspected = 0
	verify(Story.inspection_response(sample).contains("未知"), "Uninspected tea never yields a grade verdict")
	var broke = at_counter(0)
	broke.cash = 0
	var invalid_before := finances(broke)
	verify(not broke.available(2) and not broke.choose(2) and finances(broke) == invalid_before, "Unaffordable bargaining cannot reroll or charge")
	print("MARKET_OUTCOME_EXAMPLES: ", examples)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	capture_enabled = "--capture-market" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	for key in examples:
		app._end_session("completed")
		app.model.reset(int(examples[key]))
		var female: bool = key.begins_with("2")
		verify(app.set_player_profile(app.character_profiles[1 if female else 0]), "Both protagonists enter market")
		await app._tour_tap("start")
		for i in [0, 1]: await app._tour_tap("choice_%d" % i)
		await capture(key + "_01_market")
		await app._tour_tap("choice_%d" % (int(examples[key]) % 3))
		var fixed := finances(app.model)
		await app._tour_tap("market_talk")
		verify(app.player_actor.speaking and not app.npc_actor.speaking, "Question is spoken by the protagonist")
		await process_frame
		layout(app.page)
		await capture(key + "_02_questions")
		await app._tour_tap("choice_1")
		verify(finances(app.model) == fixed, "Native question is free")
		verify(str(app._story()[1]).contains("取这批货"), "Chosen topic has spoken response")
		await capture(key + "_03_answer")
		await app._tour_tap("help")
		app._market_conversation(true, app.model.revision)
		verify(app.model.stage == "bargain", "Overlay blocks market conversation")
		await app._tour_tap("close_help")
		await app._tour_tap("choice_%s" % key.left(1))
		verify(app.model.stage == "bargain_result" and app.current_location == "market", "Native deal does not skip merchant reply")
		verify(app.market_exchange.active, "Payment animation starts")
		verify(app.npc_actor.reaction == ("refuse" if app.model.bargain_result.delay > 0 else "agree"), "Merchant motion follows actual outcome")
		app.test_mode = false
		app._choose(0, "bargain_result", app.model.revision)
		verify(app.model.bargain_beat == 0, "Normal play waits for exchange animation before advancing")
		app.test_mode = true
		await process_frame
		layout(app.page)
		await capture(key + "_04_payment", 0.25)
		fixed = finances(app.model)
		var ticket: int = app.model.revision
		await app._tour_tap("choice_0")
		verify(app._story()[0] == app.avatar_profile.display_name, "Reply uses selected protagonist")
		verify(app.market_exchange.receiving, "Receipt handover animation starts")
		app._choose(0, "bargain_result", ticket)
		verify(app.model.bargain_beat == 1, "Double tap cannot skip player's reply")
		await capture(key + "_05_receipt", 0.4)
		await app._tour_tap("choice_0")
		verify(app.current_location == "inspection" and finances(app.model) == fixed, "Native exchange preserves purchase and moves to inspection")
		await capture(key + "_06_inspection")
		# Explicit low-grade fixture verifies the callback after a full inspection.
		app.model.quality = 72
		app.model.contract.quality = 86
		await app._tour_tap("choice_2")
		for i in 3: await app._tour_tap("observe_%d" % i)
		await app._tour_tap("inspection_done")
		verify(str(app._story()[1]).contains("处理") or str(app._story()[1]).contains("补救"), "Observed undergrade tea prompts a remedy response")
		await capture(key + "_07_quality_callback")
		app.model.result = {"profit":-10}
		verify(not Story.ending_echo(app.model).is_empty(), "Ending recalls committed market decision")
	print("V6_MARKET_PASS: %d checks; 600 seeded deals, optional questions, five outcomes, native touch, dual protagonists, receipts and downstream callbacks." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit(0)
