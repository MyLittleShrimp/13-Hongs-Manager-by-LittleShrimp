extends SceneTree
const Story = preload("res://scripts/commission_story.gd")
const Gestures = preload("res://tests/gesture_test_driver.gd")
var app
var checks := 0
var capture_enabled := false

func verify(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		push_error(detail)
		quit(1)
		assert(false, detail)

func _initialize() -> void:
	call_deferred("run")

func fixed() -> Array:
	return [app.model.cash, app.model.ticks, app.model.quality, app.model.rng.state, app.model.ledger.duplicate(true)]

func layout(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			verify(child.size.x <= box.size.x+2 and child.size.y <= box.size.y+2, "Commission and loading text fits: " + str(child.name))
		layout(child)

func tap(id: String) -> void:
	if not app.test_mode and app.transition_guard > 0: await create_timer(app.transition_guard + 0.03).timeout
	await app._tour_tap(id)

func capture(name: String, wait: float = 0.0) -> void:
	if not capture_enabled: return
	if wait > 0: await create_timer(wait).timeout
	app.dialogue_clock = 1000
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.9/screens")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "Actual GPU frame")

func finish_performance() -> void:
	var revision: int = app.model.revision
	if app.gesture_workshop.active: await Gestures.perform(app)
	var deadline := Time.get_ticks_msec() + 4500
	while app.action_busy and app.model.revision == revision and Time.get_ticks_msec() < deadline: await process_frame
	verify(not app.action_busy or app.model.revision != revision, "Work commits once after its performance or gesture")
	await process_frame

func packing_fixture(contract_index: int) -> void:
	app._end_session("test")
	app.test_mode = true
	app.model.reset(1)
	app.model.start()
	for i in [0,contract_index,0,0,0,0,0,0]: verify(app.model.choose(i), "Legal route to packing")
	if app.model.stage == "shipment_review": verify(app.model.choose(1), "Known risk confirmed")
	verify(app.model.stage == "packing", "Ready to select packaging")
	app._render()
	await tap("choice_1")
	verify(app.model.stage == "packing_work", "Packing paid once")
	await create_timer(0.8).timeout

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	capture_enabled = "--capture-commissions" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	app.logger.enabled = false
	app.test_mode = true
	await tap("start")
	await tap("choice_0")
	layout(app.page)
	verify(app.page.get_node("Commission_0") != null and app.page.get_node("Commission_2") != null, "Three visible commission stories before choosing")
	await capture("01_three_commissions", 0.8)
	var openings := {}
	for i in 3:
		app.model.reset(1)
		app.model.start()
		app.model.choose(0)
		app.model.choose(i)
		app._render()
		await process_frame
		openings[app._story()[1]] = true
		verify(app.model.events[0].detail.contains(Story.profile(app.model.contract).title), "Accepted commission appears in the journey")
		var money := fixed()
		await tap("commission")
		layout(app.overlay)
		await capture("02_letter_" + str(i), 0.3)
		await tap("close_help")
		verify(fixed() == money, "Reading letter does not spend or reroll")
	verify(openings.size() == 3, "Three commissions receive distinct market openings")
	# Real timed packing, with the selected female protagonist.
	await packing_fixture(2)
	app.avatar_profile = app.character_profiles[1].duplicate(true)
	app.player_actor.set_profile(app.avatar_profile)
	app._render()
	app.test_mode = false
	var money := fixed()
	for i in 3:
		await tap("tool_%d" % i)
		await tap("pack_action")
		verify(app.action_busy and app.model.packing_step == i, "Packing waits for the visible action")
		verify(app.ui_buttons.pack_action.disabled and app.packing_effect.performing, "Cannot double pack during the animation")
		await create_timer(0.45 if i < 2 else 1.35).timeout
		await capture("03_packing_" + str(i))
		if i == 1:
			await tap("commission")
			var elapsed: float = app.workshop_performance.elapsed
			await create_timer(0.3).timeout
			verify(is_equal_approx(elapsed, app.workshop_performance.elapsed), "Letter pauses packing")
			await tap("close_help")
		app._choose(0, "packing_work", app.model.revision)
		await finish_performance()
		verify(app.model.packing_step == i+1 and fixed() == money, "One packing step without repeat charge or RNG")
	verify(app.model.stage == "packing_seal", "Sealed chest remains visible before dock")
	await capture("04_sealed", 0.5)
	await tap("choice_0")
	verify(app.model.stage == "loading_work" and app.current_location == "dock", "Boatman receives the ten crates at the dock")
	for i in 3:
		var ticket: int = app.model.revision
		var count: int = app.model.loaded_count()
		await tap("loading_action")
		verify(app.action_busy and app.model.loaded_count() == count, "Loading count waits for the batch to land")
		verify(app.ui_buttons.loading_action.disabled, "Repeated loading taps are disabled")
		await create_timer(0.55).timeout
		await capture("05_loading_" + str(i))
		if i == 0:
			await tap("scene_art")
			var progress: float = app.gesture_workshop.progress()
			await create_timer(0.3).timeout
			verify(is_equal_approx(progress, app.gesture_workshop.progress()), "Looking at original pauses the loading gesture")
			await tap("close_help")
		await finish_performance()
		verify(app.model.loaded_count() == [4,7,10][i], "Counted batches total four, seven, ten")
		verify(not app.model.choose(0, "loading_work", ticket), "Old batch callback cannot count twice")
		verify(fixed() == money, "Counting changes neither cash, quality, time nor random draws")
	verify(app.model.stage == "dock" and app.model.cargo_event == "", "Route and voyage randomness wait for the player's next choice")
	await capture("06_loaded_route", 0.5)
	# Distinct truthful endings: deadline and money, grade and deadline, damage, resale.
	app.test_mode = true
	for index in 3:
		app.model.contract = app.model.data.contracts[index].duplicate(true)
		app.model.stage = "epilogue"
		app.model.result = {"mode":"standard","contract_met":true,"quality_met":true,"late":0,"penalty":0,"quality":92,"lost":0,"delivered":10,"profit":35,"funding_gap":0}
		# Synthetic settlement fixtures keep the HUD consistent with the ending under test.
		app.model.ticks = app.model.contract.deadline
		app.model.cash = int(app.model.data.initial_cash) + 35
		app.model.quality_report = "到货货色 92 / 100"
		var text: Dictionary = Story.closing(app.model)
		var delivered_story: String = text.buyer
		verify(text.master.contains("35币") and not text.master.contains("未完全履约"), "Profit is read from settlement")
		app._render()
		await process_frame
		layout(app.page)
		await capture("07_ending_success_" + str(index), 0.8)
		app.model.result.profit = -17
		text = Story.closing(app.model)
		verify(text.master.contains("亏了17币") and text.buyer == delivered_story, "Successful delivery can still lose money")
		app.model.result.contract_met = false
		app.model.result.late = 2
		app.model.result.penalty = 48
		text = Story.closing(app.model)
		verify(text.buyer.contains("2天"), "Actual lateness is reflected in every commission")
		if index == 1:
			app.model.ticks = app.model.contract.deadline + 2
			app.model.cash = int(app.model.data.initial_cash) - 17
			app._render()
			await capture("08_urgent_late_loss", 0.4)
		app.model.result.late = 0
		app.model.result.quality_met = false
		app.model.result.quality = 84
		app.model.result.mode = "discount"
		text = Story.closing(app.model)
		verify(not text.buyer.contains("合约的交代") and not text.buyer.contains("按约交清"), "Discounted undergrade is not narrated as compliant")
		app.model.result.quality_met = true
		app.model.result.lost = 3
		app.model.result.delivered = 7
		text = Story.closing(app.model)
		verify(text.buyer.contains("3箱") or text.buyer.contains("7箱"), "Actual shortages remain visible despite adequate grade")
		app.model.result.mode = "resale"
		verify(Story.closing(app.model).buyer.contains("原单已取消"), "Resale does not complete the original commission")
		app.model.result.funding_gap = 12
		verify(Story.closing(app.model).master.contains("还差12币"), "Outstanding debt is not erased by the story")
	# Exiting during a batch cancels it; a new visitor starts at zero crates.
	await packing_fixture(0)
	for i in 3:
		app.model.select_tool(i)
		app.model.choose(0)
	app.model.choose(0)
	app._render()
	app.test_mode = false
	await tap("loading_action")
	await tap("exit")
	await tap("confirm_exit")
	verify(not app.action_busy and not app.loading_effect.visible and app.model.loaded_count() == 0, "Ending cancels loading and clears the crates")
	await create_timer(2.0).timeout
	verify(app.model.stage == "attract" and app.model.loaded_count() == 0, "Cancelled timeline cannot advance the next run")
	print("COMMISSIONS_LOADING_PASS: %d checks; three letters and endings, six timed packing/loading actions, pause, cancellation, exact counts and unchanged economy." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit()
