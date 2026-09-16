extends SceneTree
var app
var assertions := 0

func check(condition: bool, detail: String) -> void:
	assertions += 1
	if not condition:
		push_error("FAIL " + detail)
		quit(1)
		assert(false, detail)

func _initialize() -> void:
	call_deferred("run")

func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	root.push_input(event, true)

func layout(node: Node) -> void:
	for child in node.get_children():
		if (child is Label or child is Button) and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			check(child.size.y <= box.size.y + 2, "Text stays in allocated height: " + child.text.left(24))
			check(child.size.x <= box.size.x + 2, "Text stays in allocated width")
			if child is Button:
				for line in child.text.split("\n"):
					var width: float = child.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
					check(width <= box.size.x - 36, "Button label not clipped: " + line)
		layout(child)

func tap(id: String, use_touch: bool = true) -> void:
	var before: String = app.model.stage
	if id == "pack_action": await app._tour_tap("tool_%d" % app.model.packing_step, use_touch)
	await app._tour_tap(id, use_touch)
	if before == "bargain" and app.model.stage == "bargain_result":
		for i in 2:
			await process_frame
			layout(app.page)
			await app._tour_tap("choice_0", use_touch)
	if before == "inspection" and app.model.stage == "inspection_work":
		await process_frame
		layout(app.page)
		check(app.model.inspected == 0, "Grade not exposed before station completes")
		for i in app.model.inspection_level + 1:
			await app._tour_tap("observe_%d" % i, use_touch)
			await process_frame
			layout(app.page)
		await app._tour_tap("inspection_done", use_touch)
	if before == "remedy" and app.model.stage == "roast_plan":
		await process_frame
		layout(app.page)
		await app._tour_tap("choice_0", use_touch)
		for i in 3:
			await process_frame
			layout(app.page)
			check(app.ui_buttons.work_action.disabled, "Work requires taking tool")
			await app._tour_tap("tool_%d" % i, use_touch)
			await app._tour_tap("work_action", use_touch)
	if before == "voyage" and app.model.stage == "voyage_report": await app._tour_tap("choice_0", use_touch)
	if before == "packing_work" and app.model.stage == "packing_seal":
		await app._tour_tap("choice_0", use_touch)
		for i in 3: await app._tour_tap("loading_action", use_touch)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.logger.enabled = false
	check(app.model.stage == "attract", "Boot attract")
	check(not app.settings.kiosk_mode, "Single-player defaults to no visitor timeout")
	app.model.start()
	app.test_mode = false
	app._process(180)
	check(app.model.stage == "intro", "Single-player does not reset while thinking")
	app.model.reset(121)
	app.test_mode = true
	app._render()
	app.settings.kiosk_mode = true
	await process_frame
	layout(app.page)
	var profile: Dictionary = app.avatar_profile.duplicate(true)
	profile.display_name = "测试管事"
	check(app.set_player_profile(profile), "Whole-body avatar replaceable")
	check(app.player_actor.profile.display_name == "测试管事", "Actor receives avatar profile")
	check(not app.set_player_profile({"body_texture":"res://missing.png"}), "Missing avatar rejected")
	# A runtime PNG from the future avatar producer works without an editor import.
	var picture: Image = load(profile.body_texture).get_image()
	check(picture.save_png("user://avatar_test.png") == OK, "Runtime avatar fixture")
	profile.body_texture = "user://avatar_test.png"
	check(app.set_player_profile(profile), "Runtime user PNG avatar accepted")
	DirAccess.remove_absolute("user://avatar_test.png")
	await tap("start")
	check(app.model.stage == "intro", "Native touch starts")
	await tap("choice_0")
	await process_frame
	layout(app.page)
	await tap("choice_0")
	check(app.model.stage == "market" and app.model.cash == 220, "One prepaid order")
	app.model.cash = 18
	app._render()
	await process_frame
	layout(app.page)
	check(app.ui_buttons.choice_2.disabled, "Unaffordable supplier disabled")
	app.model.cash = 220
	app._render()
	var a: Vector2 = app.ui_buttons.choice_0.get_global_rect().get_center()
	var b: Vector2 = app.ui_buttons.choice_1.get_global_rect().get_center()
	touch(0, a, true)
	touch(1, b, true)
	touch(1, b, false)
	check(app.model.stage == "market", "Secondary finger cannot commit")
	touch(0, a, false)
	await process_frame
	check(app.model.stage == "bargain" and app.model.cash == 220, "Supplier reservation is not payment")
	await tap("choice_0")
	check(app.model.stage == "inspection", "Purchase")
	var paid: int = app.model.cash
	app._choose(0, "bargain")
	check(app.model.cash == paid, "Stale button cannot pay twice")
	await tap("help")
	var stage: String = app.model.stage
	await tap("choice_0")
	check(app.model.stage == stage, "Modal blocks scene choices")
	await tap("close_help")
	app.test_mode = false
	app.transition_guard = 1.0
	app._choose(0, "inspection")
	check(app.model.stage == "inspection", "Animation guard blocks rapid tap")
	app.transition_guard = 0
	app.idle_seconds = 44.0
	app._process(1.1)
	check(app.overlay_kind == "idle", "Idle prompt at 45 seconds")
	await tap("resume")
	check(app.model.stage == "inspection" and app.model.cash == paid, "Resume retains trade")
	app.idle_seconds = 59.9
	app._process(0.2)
	check(app.model.stage == "attract" and app.model.ledger.is_empty(), "Idle fully resets")
	check(app.avatar_profile.display_name == app.default_avatar_profile.display_name, "Next visitor receives default avatar")
	app.test_mode = true
	await tap("start")
	await tap("help")
	app.test_mode = false
	app.idle_seconds = 70
	app._process(0.1)
	check(app.overlay_kind == "help" and app.model.stage == "intro", "90 second reading allowance")
	app.idle_seconds = 90
	app._process(0.1)
	check(app.model.stage == "attract", "Reading eventually resets")
	app.test_mode = true
	# Traverse all primary stages with native touchscreen events, checking layout and funds.
	await tap("start")
	for i in [0, 1, 0, 2, 1, 0]:
		await tap("choice_%d" % i)
		await process_frame
		layout(app.page)
	if app.model.stage == "shipment_review": await tap("choice_1")
	await tap("choice_1")
	check(app.model.stage == "packing_work", "Dedicated packing scene")
	for i in 3:
		await tap("pack_action")
		await process_frame
		layout(app.page)
	check(app.model.stage == "dock", "Sealed cargo moves to dock")
	await tap("choice_0")
	check(app.model.stage == "voyage", "Random voyage event")
	await process_frame
	layout(app.page)
	await tap("choice_1")
	if app.model.stage == "acceptance":
		await process_frame
		layout(app.page)
		await tap("choice_0")
	await tap("choice_0")
	check(app.model.stage == "result", "Complete actual touch settlement")
	await process_frame
	layout(app.page)
	await tap("review")
	await process_frame
	layout(app.overlay)
	await tap("close_help")
	await tap("choice_0")
	await tap("finish")
	# Visitor's known-quality scenario, injected solely as a regression fixture.
	await tap("start")
	for i in [0, 2, 1, 0]: await tap("choice_%d" % i)
	app.model.quality = 72
	await tap("choice_2")
	await process_frame
	layout(app.page)
	var ticket: int = app.model.revision
	await tap("choice_1")
	check(app.model.quality == 84 and app.model.stage == "remedy", "One treatment keeps player at the tea stall")
	var saved_cash: int = app.model.cash
	app._choose(1, "remedy", ticket)
	check(app.model.cash == saved_cash and app.model.quality == 84, "Stale same-stage treatment button blocked")
	await process_frame
	layout(app.page)
	await tap("support")
	await process_frame
	layout(app.overlay)
	await tap("borrow")
	check(app.model.cash == saved_cash + 60 and app.model.debt_due() == 66, "Loan via native touch")
	await tap("choice_1")
	check(app.model.quality == 96 and app.ui_buttons.choice_1.disabled, "Second treatment then cap")
	await tap("choice_0")
	check(app.model.stage == "packing", "Treated tea proceeds")
	app.model._book("ui_zero_fixture", "测试前序开支", -app.model.cash)
	app._render()
	await tap("support")
	await process_frame
	layout(app.overlay)
	check(app.ui_buttons.borrow.disabled and not app.ui_buttons.defer.disabled, "Used loan doesn't block deferred fallback")
	await tap("defer")
	for i in 3: await tap("pack_action")
	await tap("support")
	await tap("defer")
	check(app.model.debt_due() == 96 and app.model.cash == 0, "Zero-cash voyage with 96 owed")
	await tap("choice_1")
	if app.model.stage == "acceptance": await tap("choice_0")
	await tap("choice_0")
	check(app.model.stage == "result" and app.model.debt_due() == 0, "Emergency route settles")
	await tap("review")
	await process_frame
	layout(app.overlay)
	await tap("close_help")
	await tap("choice_0")
	await tap("finish")
	await tap("start", false)
	check(app.model.stage == "intro", "Mouse starts")
	await tap("exit", false)
	await tap("confirm_exit", false)
	check(app.model.stage == "attract", "Mouse exits")
	print("V4_UI_PASS: %d checks; touch, modal, repeat treatment, credit, deferred fallback, settlement, layout." % assertions)
	app.queue_free()
	await create_timer(0.3).timeout
	quit(0)
