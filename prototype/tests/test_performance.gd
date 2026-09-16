extends SceneTree
const Display = preload("res://scripts/quality_display.gd")
const Gestures = preload("res://tests/gesture_test_driver.gd")
var app
var checks := 0
var capture_enabled := false

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false, message)

func _initialize() -> void:
	call_deferred("run")

func tap(id: String) -> void:
	if not app.test_mode and app.transition_guard > 0:
		await create_timer(app.transition_guard + 0.03).timeout
	await app._tour_tap(id)

func wait_for_performance() -> void:
	if app.gesture_workshop.active: await Gestures.perform(app)
	var deadline := Time.get_ticks_msec() + 5000
	while app.action_busy and Time.get_ticks_msec() < deadline: await process_frame
	verify(not app.action_busy, "Performance finishes in bounded time")
	await process_frame

func layout(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			verify(child.size.x <= box.size.x + 2 and child.size.y <= box.size.y + 2, "Result and performance text fits " + child.name)
		layout(child)

func capture(name: String) -> void:
	if not capture_enabled: return
	# Equivalent to the player's “全文” button; keep the screenshot readable.
	app.dialogue_clock = 1000
	if not app.action_busy: await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.7")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "Capture actual engine frame")

func setup(grade: int, level: int, threshold: int = 86) -> void:
	app._end_session("completed")
	app.test_mode = true
	app.model.reset(1)
	app.model.start()
	for choice in [0, 2, 0, 0, 0, 0]: verify(app.model.choose(choice), "Purchase fixture through legal actions")
	app.model.quality = grade
	app.model.contract.quality = threshold
	verify(app.model.choose(level), "Pay once for selected inspection")
	app._render()
	await create_timer(0.8 if capture_enabled else 0.02).timeout

func center_text(name: String) -> String:
	var panel = app.page.get_node("QualityResult")
	verify(panel.get_global_rect().get_center().distance_to(Vector2(960, 450)) < 80, "Result is in the central scene panel")
	return panel.get_node(name).text

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	capture_enabled = "--capture-performance" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	# The exact visitor example: sampled 85 is presented as 78–92, not as known 85.
	await setup(85, 1, 65)
	app.test_mode = false
	app.transition_guard = 0
	var cash: int = app.model.cash
	var random_state: int = app.model.rng.state
	await tap("observe_0")
	verify(app.action_busy and app.model.inspection_marks.is_empty(), "Observation result waits for its visible performance")
	app._choose(0, "inspection_work", app.model.revision)
	app._station_action("finish_inspection", app.model.revision)
	app._show_support()
	verify(app.action_busy and app.overlay_kind == "" and app.model.inspection_marks.is_empty(), "Repeat clicks, early confirmation and loans cannot interrupt the observation")
	await create_timer(0.35).timeout
	await capture("01_leaf_observation")
	await tap("help")
	await process_frame
	var elapsed: float = app.gesture_workshop.progress()
	await create_timer(0.35).timeout
	verify(is_equal_approx(app.gesture_workshop.progress(), elapsed) and app.model.inspection_marks.is_empty(), "Help pauses the pending gesture")
	await tap("close_help")
	await wait_for_performance()
	verify(app.model.inspection_marks == [0] and app.model.cash == cash and app.model.rng.state == random_state, "One observation, no additional fees or random draws")
	await tap("observe_1")
	await create_timer(0.45).timeout
	await capture("02_moisture_observation")
	await wait_for_performance()
	await tap("inspection_done")
	verify(center_text("QualityValue") == "当前货色估计 78—92", "Central panel reproduces sampled interval")
	verify(center_text("QualityRequirement") == "订单要求 ≥ 65", "Target appears beside observed result")
	layout(app.page)
	await capture("03_sample_result_78_92")
	# Sampled processing preserves uncertainty and clamps the displayed interval at 100.
	app.test_mode = true
	await tap("choice_1")
	await tap("choice_0")
	for i in 3:
		await tap("tool_%d" % i)
		await tap("work_action")
	verify(center_text("QualityValue") == "当前货色估计 90—100", "Processed sample retains a range")
	verify(center_text("QualityComparison").contains("78—92 → 90—100"), "Central sample before/after comparison")
	# Female protagonist, full inspection and the complete timed roast, including cooling.
	await setup(72, 2)
	app.avatar_profile = app.character_profiles[1].duplicate(true)
	app.player_actor.set_profile(app.avatar_profile)
	app._render()
	for i in [0, 1]: await tap("observe_%d" % i)
	app.test_mode = false
	app.transition_guard = 0
	await tap("observe_2")
	await create_timer(0.45).timeout
	await capture("04_tea_soup_observation")
	await wait_for_performance()
	await tap("inspection_done")
	verify(center_text("QualityValue") == "当前货色 72", "Full inspection shows the exact value centrally")
	await tap("choice_1")
	await tap("choice_0")
	cash = app.model.cash
	var ticks: int = app.model.ticks
	random_state = app.model.rng.state
	for i in 3:
		await tap("tool_%d" % i)
		await tap("work_action")
		verify(app.action_busy and app.model.roast_step == i and app.model.quality == 72, "Roast step commits only after its performance")
		verify(app.ui_buttons.work_action.disabled, "No repeat action during work")
		await create_timer(0.5).timeout
		layout(app.page)
		await capture(["05_charcoal", "06_turning_tea", "07_cooling"][i])
		if i == 2: verify(app.current_location == "roasting" and app.gesture_workshop.kind == "sieve", "Final cooling stays in the roasting room")
		await wait_for_performance()
		verify(app.model.cash == cash and app.model.ticks == ticks and app.model.rng.state == random_state, "Animation adds no money, time or random changes")
	verify(app.model.quality == 84 and app.current_location == "inspection", "Finish cooling then return with quality 84")
	verify(center_text("QualityValue") == "当前货色 84", "Processed exact grade visible centrally")
	verify(center_text("QualityComparison").contains("72 → 84"), "Exact before/after comparison")
	verify(app._story()[0] == "陈叔" and str(app._story()[1]).contains("还没到"), "Mentor reacts to remaining shortfall")
	verify(str(app.npc_actor.profile.body_texture).ends_with("master.png"), "The visible speaker matches the mentor's response")
	await create_timer(0.8).timeout
	await capture("08_roast_result_72_84")
	layout(app.page)
	app.test_mode = true
	await tap("choice_1")
	await tap("choice_0")
	for i in 3:
		await tap("tool_%d" % i)
		await tap("work_action")
	verify(center_text("QualityComparison").contains("84 → 96"), "Second roast compares against the first result")
	await capture("09_second_roast_result")
	# Unknown quality remains unknown, including after a treatment.
	await setup(72, 0)
	verify(center_text("QualityValue") == "当前货色未知", "Uninspected quality remains hidden")
	await tap("choice_2")
	verify(not center_text("QualityComparison").contains("72") and Display.headline(app.model) == "当前货色未知", "Exchange cannot expose hidden exact grade")
	await capture("10_unknown_quality")
	# Cancel an active observation. No late callback may alter the next trade.
	await setup(72, 1)
	app.test_mode = false
	app.transition_guard = 0
	await tap("observe_0")
	await tap("exit")
	await tap("confirm_exit")
	verify(not app.action_busy and not app.workshop_performance.active, "Ending cancels pending work")
	app.test_mode = true
	await tap("start")
	var revision: int = app.model.revision
	await create_timer(1.6).timeout
	verify(app.model.stage == "intro" and app.model.revision == revision and app.model.last_treatment.is_empty(), "Cancelled performance cannot affect a new session")
	print("V7_PERFORMANCE_PASS: %d checks; central estimates/exact/unknown values, comparisons, six timed actions, pause/resume, double taps and cancellation." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit(0)
