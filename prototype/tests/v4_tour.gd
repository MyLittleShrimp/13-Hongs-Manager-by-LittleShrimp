extends RefCounted
## Render QA only. Every injected grade/weather is explicitly a test fixture.
var app

func tap(id: String) -> void:
	var before: String = app.model.stage
	await app._tour_tap(id)
	if before == "bargain" and app.model.stage == "bargain_result":
		for i in 2: await app._tour_tap("choice_0")

func capture(id: String) -> void:
	await app._capture(id)

func work(roast: bool) -> void:
	for i in 3:
		await tap("tool_%d" % i)
		await tap("work_action" if roast else "pack_action")

func run(application) -> void:
	app = application
	await app.get_tree().process_frame
	await capture("00_title")
	await tap("start")
	for i in [1,2,0,0]: await tap("choice_%d" % i)
	app.model.quality = 72
	await capture("01_inspection_room")
	await tap("choice_2")
	await capture("02_tea_observation")
	await tap("observe_0")
	await capture("03_leaf_clue")
	await tap("observe_1")
	await tap("observe_2")
	await tap("inspection_done")
	await tap("choice_1")
	await capture("04_fire_plans")
	await tap("choice_0")
	await tap("tool_0")
	await capture("05_charcoal")
	await tap("work_action")
	await tap("tool_1")
	await capture("06_turning_tea")
	await tap("work_action")
	await tap("tool_2")
	await capture("07_cooling")
	await tap("work_action")
	assert(app.model.quality == 84)
	await capture("08_processed84")
	await tap("support")
	await tap("borrow")
	await tap("choice_1")
	await tap("choice_0")
	await work(true)
	assert(app.model.quality == 96)
	await tap("choice_0")
	await tap("choice_1")
	await capture("09_packing_materials")
	await tap("tool_0")
	await tap("pack_action")
	await capture("10_lining")
	await tap("tool_1")
	await tap("pack_action")
	await capture("11_filled_tea")
	await tap("tool_2")
	await tap("pack_action")
	assert(app.model.stage == "packing_seal")
	await capture("12_sealed")
	await tap("choice_0")
	for i in 3: await tap("loading_action")
	await tap("choice_1")
	await capture("13_aboard")
	await tap("choice_1")
	await capture("14_onboard_report")
	await tap("choice_0")
	if app.model.stage == "acceptance": await tap("choice_0")
	await capture("15_buyer")
	await tap("choice_0")
	await capture("16_result")
	await tap("choice_0")
	await capture("17_ending")
	await tap("journey")
	await capture("18_journey")
	await tap("close_help")
	await tap("finish")
	# A separate real trade with explicitly injected low-grade/storm QA fixtures.
	await tap("start")
	for i in [0,2,0,0,0,0]: await tap("choice_%d" % i)
	if app.model.stage == "shipment_review": await tap("choice_1")
	await tap("choice_0")
	await work(false)
	await tap("choice_0")
	await tap("choice_0")
	app.model.quality = 72
	app.model.cargo_event = "squall"
	app.model.last_line = "风忽然紧了！先照应船舱里的茶箱，再决定是避风还是赶路。"
	var probe := RandomNumberGenerator.new()
	for seed_value in 1000:
		probe.seed = seed_value
		if probe.randf() < app.model.risk(1):
			app.model.rng.seed = seed_value
			break
	app._render()
	await capture("19_storm")
	await tap("choice_1")
	assert(app.model.stage == "voyage_report" and app.model.pending_delivery.damaged)
	await capture("20_wet_cargo")
	await tap("choice_0")
	assert(app.model.stage == "acceptance")
	await capture("21_undergrade_buyer")
	await tap("choice_1")
	await tap("choice_0")
	await capture("22_resale_result")
	await tap("choice_0")
	await capture("23_resale_ending")
	print("V4_UI_TOUR_PASS: native touch; explicit grade/storm QA fixtures; inspection, three-step roast, packing/seal, cargo, buyer, outcome stories.")
	app.get_tree().quit(0)
