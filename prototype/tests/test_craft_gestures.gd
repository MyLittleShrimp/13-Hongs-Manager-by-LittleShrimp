extends SceneTree
const Driver = preload("res://tests/gesture_test_driver.gd")
const Trade = preload("res://scripts/trade_session.gd")
var app
var checks := 0
var captures := false
var oracle

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false,message)

func _initialize() -> void:
	call_deferred("run")

func fixed(model = null) -> Array:
	var m = app.model if model == null else model
	return [m.cash,m.ticks,m.quality,m.rng.state,m.ledger.duplicate(true)]

func capture(name: String) -> void:
	if not captures: return
	app.dialogue_clock = 1000
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.11/screens")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Actual craft screenshot")

func tap(id: String) -> void:
	await Driver.wait_ready(app,"touch")
	await app._tour_tap(id)

func fixture(kind: String) -> void:
	app._end_session("test")
	app.test_mode = true
	app.model.reset(1)
	app.model.start()
	for i in [0,2,0,0,0,0]: verify(app.model.choose(i),"Legal purchase")
	app.model.quality = 72
	if kind in ["spread","knead","fire","sieve"]:
		verify(app.model.choose(2),"Pay inspection")
		if kind in ["fire","sieve"]:
			for i in 3: verify(app.model.choose(i),"Inspect")
			verify(app.model.finish_inspection(),"Read results")
			verify(app.model.choose(1) and app.model.choose(0),"Pay roast")
			if kind == "sieve":
				for i in 2: verify(app.model.select_tool(i) and app.model.choose(0),"Earlier roast work")
	else:
		verify(app.model.choose(0) and app.model.choose(0),"No inspection route")
		if app.model.stage == "shipment_review": verify(app.model.choose(1),"Accept risk")
		verify(app.model.choose(1),"Pay packaging")
		var steps := {"liner":0,"pour":1,"seal":2}
		for i in steps[kind]: verify(app.model.select_tool(i) and app.model.choose(0),"Earlier packing work")
	app.test_mode = false
	app._render()
	await create_timer(0.85).timeout
	if kind in ["spread","knead"]: await tap("observe_0" if kind == "spread" else "observe_1")
	await Driver.wait_ready(app,"touch")

func begin_tool(device: String = "touch") -> Vector2:
	await Driver.wait_ready(app,device)
	var index: int = app.model.roast_step if app.model.stage == "roasting_work" else app.model.packing_step
	var pos: Vector2 = app.ui_buttons["tool_%d" % index].get_global_rect().get_center()
	Driver.edge(app,pos,true,device)
	verify(app.gesture_workshop.captured and app.action_busy,"Tool down starts the original held gesture")
	verify(not app.ui_buttons["work_action" if app.model.stage == "roasting_work" else "pack_action"].visible,"No second start button")
	return pos

func observations() -> void:
	await fixture("spread")
	var g = app.gesture_workshop
	var before := fixed()
	for side in [-1,1,-1,1]:
		Driver.edge(app,g.LEAVES+Vector2(side*140,0),true)
		Driver.edge(app,g.LEAVES+Vector2(side*140,0),false)
	verify(g.progress() == 0,"Endpoint clicks cannot spread leaves")
	Driver.edge(app,g.LEAVES,true)
	Driver.move(app,g.LEAVES-Vector2(145,0))
	Driver.edge(app,g.LEAVES-Vector2(145,0),false)
	verify(g.progress() == 0.5 and app.model.inspection_marks.is_empty(),"One side remains partial")
	await capture("01_spread_leaves")
	app._show_history()
	await create_timer(0.3).timeout
	verify(g.progress() == 0.5,"Modal preserves spread progress")
	app._close_overlay()
	await Driver.perform(app,"mouse")
	verify(app.model.inspection_marks == [0] and fixed() == before,"Spread records one observation without economic changes")
	await fixture("knead")
	before = fixed()
	for side in [-1,1,-1,1,-1]:
		Driver.edge(app,g.PINCH+Vector2(side*50,0),true)
		Driver.edge(app,g.PINCH+Vector2(side*50,0),false)
	verify(g.swings == 0,"Separate clicks cannot replace kneading")
	Driver.edge(app,g.PINCH,true)
	for i in 30: Driver.move(app,g.PINCH+Vector2(5 if i%2 else -5,0))
	Driver.edge(app,g.PINCH,false)
	verify(g.swings == 0,"Small jitter cannot knead")
	Driver.edge(app,g.PINCH,true)
	for side in [-1,1,-1]: Driver.move(app,g.PINCH+Vector2(side*50,0))
	Driver.edge(app,g.PINCH-Vector2(50,0),false)
	verify(g.swings == 2,"A partial knead is retained")
	await capture("02_knead_sample")
	await Driver.perform(app)
	verify(app.model.inspection_marks == [1] and fixed() == before,"Knead records one observation")
	verify(app.model.last_line.contains("韧性"),"Observation uses the existing quality clue")

func roasting() -> void:
	await fixture("fire")
	var g = app.gesture_workshop
	var before := fixed()
	var pos := await begin_tool("mouse")
	var revision: int = app.model.revision
	Driver.edge(app,pos,true,"touch")
	Driver.move(app,g.FIRE,"touch")
	Driver.move(app,g.FIRE-Vector2(140,0),"touch")
	verify(app.model.revision == revision and g.left_extent == 1,"Mouse-to-touch takeover selects the tool once")
	await capture("03_fire_direct_drag")
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Driver.edge(app,g.FIRE+Vector2(140,0),false,"touch")
	verify(not g.captured and app.model.roast_step == 0,"Focus loss cancels a held fire stroke")
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	await Driver.perform(app)
	verify(app.model.roast_step == 1 and fixed() == before,"Fire gesture preserves money, time, grade and RNG")
	await fixture("sieve")
	before = fixed()
	pos = await begin_tool()
	await Driver.travel(app,pos,g.COOL)
	Driver.edge(app,g.COOL,false)
	verify(g.phase == 0 and app.model.quality == 72,"Cannot skip collection and go straight to cooling")
	Driver.edge(app,g.object_position,true)
	await Driver.travel(app,g.object_position,g.COLLECT)
	await create_timer(0.55).timeout
	verify(g.phase == 1 and app.model.quality == 72,"Collected tea has not yet earned the roast gain")
	await capture("04_sieve_collected")
	app._show_help()
	await create_timer(0.4).timeout
	await capture("11_help_all_gestures")
	verify(g.phase == 1 and not g.captured and app.model.quality == 72,"Help retains the collected tea")
	app._close_overlay()
	await Driver.perform(app,"mouse")
	verify(app.model.stage == "remedy" and app.model.quality == 84,"Cooling earns exactly the original gain")
	var after := fixed()
	after[2] = 72
	verify(after == before,"Cooling adds no extra money, time or RNG effects")

func packing() -> void:
	await fixture("liner")
	var g = app.gesture_workshop
	var before := fixed()
	var pos := await begin_tool()
	await Driver.travel(app,pos,g.BOX)
	Driver.edge(app,g.BOX,false)
	verify(g.phase == 1 and app.model.packing_step == 0,"Dropping paper opens it without finishing the wipe")
	Driver.edge(app,g.WIPE_END,true)
	Driver.edge(app,g.WIPE_END,false)
	verify(g.amount == 0,"Wipe endpoint click does not finish")
	Driver.edge(app,g.WIPE_START,true)
	Driver.move(app,g.WIPE_START.lerp(g.WIPE_END,0.45))
	Driver.edge(app,g.WIPE_START.lerp(g.WIPE_END,0.45),false)
	await capture("05_liner_wipe")
	app._show_commission()
	app._close_overlay()
	await Driver.perform(app)
	verify(app.model.packing_step == 1 and fixed() == before,"Paper wipe commits once")
	# Light tap arms the next action immediately and parks the basket near the work.
	await tap("tool_1")
	verify(g.active and g.kind == "pour" and not g.captured,"Light tap provides nearby pickup without a start button")
	Driver.move(app,g.POUR)
	await create_timer(1.25).timeout
	verify(g.amount == 0,"Hovering cannot pour")
	Driver.edge(app,g.object_position,true)
	await Driver.travel(app,g.object_position,g.POUR)
	await create_timer(0.4).timeout
	verify(g.amount > 0.2 and g.amount < 0.7,"Pour requires dwell while held")
	await capture("06_pouring_tea")
	Driver.move(app,g.POUR+Vector2(210,150))
	var partial: float = g.amount
	await create_timer(0.4).timeout
	verify(g.amount == partial,"Leaving the mouth pauses the pour")
	app._show_history()
	await create_timer(0.4).timeout
	verify(g.amount == partial and not g.captured,"Modal cannot keep pouring")
	app._close_overlay()
	await Driver.perform(app)
	verify(app.model.packing_step == 2 and fixed() == before,"Resumed pour does not spill or recharge")
	pos = await begin_tool()
	await Driver.travel(app,pos,Vector2(690,630))
	Driver.edge(app,Vector2(690,630),false)
	verify(g.kind == "seal" and not g.lid_closed,"Wrong lid drop cannot start ropes")
	await capture("07_lid_ready")
	await Driver.complete_lid(app)
	verify(g.kind == "rope" and g.lid_closed and app.model.packing_step == 2,"Lid drop opens the rope gesture without a separate click")
	await process_frame
	verify(app.packing_effect.manual_rope and not app.packing_effect.manual_lid_open,"Automatic rope drawing stays disabled")
	await capture("08_lid_then_rope")
	app._show_help()
	app._close_overlay()
	verify(g.lid_closed and g.rope_point == 1,"Lid state survives modal")
	await Driver.perform(app)
	verify(app.model.stage == "packing_seal" and fixed() == before,"Lid and two ropes commit the original packing step once")
	await fixture("pour")
	await begin_tool()
	app._end_session("test")
	await create_timer(1.3).timeout
	verify(not g.active and not g.captured and app.model.stage == "attract","Exit cancels a pending compound gesture")

func compare() -> void:
	verify(app.model.stage == oracle.stage and fixed() == fixed(oracle),"Gesture UI matches economic oracle at "+app.model.stage)

func choose(index: int) -> void:
	verify(oracle.choose(index),"Reference choice")
	await tap("choice_%d" % index)
	compare()

func trade(with_roast: bool) -> void:
	app._end_session("test")
	app.model.reset(17)
	oracle = Trade.new(app.model.data.duplicate(true))
	oracle.reset(17)
	app.avatar_profile = app.character_profiles[int(with_roast)].duplicate(true)
	app.player_actor.set_profile(app.avatar_profile)
	app._render()
	await tap("start")
	verify(oracle.start(),"Reference start")
	for i in [0,0,0,0,0,0]: await choose(i)
	await choose(2 if with_roast else 0)
	if with_roast:
		for i in 3:
			await tap("observe_%d" % i)
			await Driver.perform(app)
			verify(oracle.choose(i),"Reference observation")
			compare()
		await tap("inspection_done")
		verify(oracle.finish_inspection(),"Reference inspection result")
		compare()
		await choose(1)
		await choose(0)
		for i in 3:
			await tap("tool_%d" % i)
			verify(oracle.select_tool(i),"Reference roast tool")
			await Driver.perform(app)
			verify(oracle.choose(0),"Reference roast work")
			compare()
	await choose(0)
	if app.model.stage == "shipment_review": await choose(1)
	await choose(1)
	for i in 3:
		await tap("tool_%d" % i)
		verify(oracle.select_tool(i),"Reference pack tool")
		await Driver.perform(app)
		verify(oracle.choose(0),"Reference pack work")
		compare()
	await choose(0)
	for i in 3:
		await Driver.perform(app)
		verify(oracle.choose(0),"Reference load")
		compare()
	await choose(0)
	await choose(1)
	await choose(0)
	if app.model.stage == "acceptance": await choose(0)
	await choose(0)
	await choose(0)
	verify(app.model.stage == "epilogue" and app.model.result == oracle.result,"Complete UI trade preserves exact settlement")
	await capture("09_trade_roast" if with_roast else "10_trade_no_roast")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.logger.enabled = false
	captures = "--capture-crafts" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	await observations()
	await roasting()
	await packing()
	await trade(true)
	await trade(false)
	print("CRAFT_GESTURES_PASS: %d checks; seven actions, held pickup, tap pickup, cancellation, pause, no shortcuts and two complete trades identical to the economic oracle." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit()
