extends SceneTree
const Driver = preload("res://tests/gesture_test_driver.gd")
var app
var checks := 0
var capture_enabled := false

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false,message)

func _initialize() -> void:
	call_deferred("run")

func fixed() -> Array:
	return [app.model.cash,app.model.ticks,app.model.quality,app.model.rng.state,app.model.ledger.duplicate(true)]

func capture(name: String) -> void:
	if not capture_enabled: return
	app.dialogue_clock = 1000
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../artifacts/v0.10/screens")
	DirAccess.make_dir_recursive_absolute(path)
	verify(root.get_texture().get_image().save_png(path.path_join(name+".png")) == OK,"Capture GPU gesture frame")

func tap(id: String) -> void:
	await Driver.wait_ready(app,"touch")
	await app._tour_tap(id)

func fixture(place: String) -> void:
	app._end_session("test")
	app.test_mode = true
	app.model.reset(1)
	app.model.start()
	for i in [0,2,0,0,0,0]: verify(app.model.choose(i),"Buy legally before work")
	app.model.quality = 72
	if place == "cup" or place == "stir":
		verify(app.model.choose(2),"Pay for full inspection")
		if place == "stir":
			for i in 3: verify(app.model.choose(i),"Inspect before roast")
			verify(app.model.finish_inspection(),"Read inspection")
			verify(app.model.choose(1) and app.model.choose(0),"Pay for normal roast")
			verify(app.model.select_tool(0) and app.model.choose(0),"Prepare fire")
			verify(app.model.select_tool(1),"Take paddle")
	else:
		verify(app.model.choose(0) and app.model.choose(0),"Uninspected route")
		if app.model.stage == "shipment_review": verify(app.model.choose(1),"Accept risk")
		verify(app.model.choose(1),"Pay for paper packaging")
		for i in 2: verify(app.model.select_tool(i) and app.model.choose(0),"Line and fill box")
		verify(app.model.select_tool(2),"Take lid and rope")
		if place == "loading":
			verify(app.model.choose(0) and app.model.choose(0),"Seal before going to dock")
	app.test_mode = false
	app.avatar_profile = app.character_profiles[1].duplicate(true)
	app.player_actor.set_profile(app.avatar_profile)
	app._render()
	await create_timer(0.9).timeout
	if place == "cup": await tap("observe_2")
	elif place == "rope": await Driver.complete_lid(app)
	verify(app.gesture_workshop.active and app.action_busy,"Expected gesture is active: "+place)
	await Driver.wait_ready(app,"touch")

func loading_checks() -> void:
	await fixture("loading")
	var g = app.gesture_workshop
	var money := fixed()
	var revision: int = app.model.revision
	await capture("01_loading_shapes")
	var start: Vector2 = g.source+g.BOX_SIZE/2
	Driver.edge(app,start,true)
	Driver.edge(app,start,false)
	await create_timer(0.6).timeout
	verify(app.model.loaded_count() == 0 and app.model.revision == revision,"Clicking a group does not load it")
	Driver.move(app,g.target+g.BOX_SIZE/2)
	verify(not g.captured and app.model.loaded_count() == 0,"Hover cannot drag")
	Driver.edge(app,start,true)
	Driver.move(app,start+Vector2(200,-70))
	Driver.edge(app,start+Vector2(200,-70),false)
	verify(g.object_position == g.source and g.feedback.contains("再试"),"Wrong drop resets safely")
	verify(fixed() == money,"Failed gestures do not spend or reroll")
	# A second finger cannot finish the first finger's drag.
	Driver.edge(app,start,true,"touch",0)
	Driver.edge(app,g.target,true,"touch",1)
	Driver.move(app,g.target+g.BOX_SIZE/2,"touch",1)
	Driver.edge(app,g.target+g.BOX_SIZE/2,false,"touch",1)
	verify(g.captured and g.object_position == g.source,"Other finger cannot move the captured group")
	Driver.edge(app,start,false,"touch",0,true)
	verify(not g.captured and app.model.loaded_count() == 0,"Canceled contact never submits")
	# Valid position is a preview until the user releases.
	Driver.edge(app,start,true)
	var end: Vector2 = g.target+g.BOX_SIZE/2
	Driver.move(app,end)
	await process_frame
	verify(g.release_ready and app.model.loaded_count() == 0,"Aligned preview is not committed while held")
	await capture("02_loading_aligned")
	app._show_history()
	verify(g.paused and not g.captured,"Opening original cancels the active drag")
	Driver.edge(app,end,false)
	await create_timer(0.5).timeout
	verify(app.model.loaded_count() == 0,"Releasing through a modal cannot load")
	app._close_overlay()
	await process_frame
	var shapes := {}
	for i in 3:
		shapes[str(g.cells)] = true
		var ticket: int = app.model.revision
		await Driver.perform(app,"mouse" if i == 1 else "touch")
		verify(app.model.loaded_count() == [4,7,10][i],"Three correct releases count exactly four, seven, ten")
		verify(not app.model.choose(0,"loading_work",ticket),"Stale completion cannot load twice")
		verify(fixed() == money,"Successful gesture preserves original economics")
		if i < 2: await capture("03_loading_round_"+str(i+2))
	verify(shapes.size() == 3 and app.model.stage == "dock","Three different layouts lead to route selection")
	await capture("04_loading_finished")
	# Reverse driver order: mouse-down followed by touch-down for one physical contact.
	await fixture("loading")
	await Driver.wait_ready(app,"mouse")
	start = g.source+g.BOX_SIZE/2
	end = g.target+g.BOX_SIZE/2
	Driver.edge(app,start,true,"mouse")
	Driver.edge(app,start,true,"touch")
	Driver.move(app,end,"touch")
	Driver.edge(app,end,false,"touch")
	Driver.edge(app,end,false,"mouse")
	await create_timer(0.6).timeout
	verify(app.model.loaded_count() == 4,"Mixed driver edges submit one batch")
	start = g.source+g.BOX_SIZE/2
	Driver.edge(app,start,true)
	Driver.move(app,g.target+g.BOX_SIZE/2)
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Driver.edge(app,g.target+g.BOX_SIZE/2,false)
	await create_timer(0.5).timeout
	verify(app.model.loaded_count() == 4 and not g.captured,"Focus loss cancels a held drop")
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame
	app._show_exit()
	await tap("confirm_exit")
	await create_timer(0.7).timeout
	verify(app.model.stage == "attract" and not g.active and app.model.loaded_count() == 0,"Exit clears all pending gestures and cargo")

func cup_checks() -> void:
	await fixture("cup")
	var g = app.gesture_workshop
	var money := fixed()
	verify(g.cup != null and g.cup.get_image().get_pixel(0,0).a == 0,"Generated cup loads with real alpha")
	await create_timer(1.6).timeout
	verify(app.model.inspection_marks.is_empty(),"Waiting does not substitute for a gesture")
	Driver.edge(app,g.object_position,true)
	for i in 30: Driver.move(app,g.CUP_CENTER+Vector2(5 if i%2 == 0 else -5,0))
	Driver.edge(app,g.object_position,false)
	verify(g.swings == 0,"Tiny pointer jitter cannot count as a shake")
	Driver.edge(app,g.object_position,true)
	Driver.move(app,g.CUP_CENTER+Vector2(-120,0))
	Driver.move(app,g.CUP_CENTER+Vector2(120,0))
	Driver.edge(app,g.object_position,false)
	verify(g.swings == 1 and app.model.inspection_marks.is_empty(),"Partial shake can be resumed")
	await capture("05_cup_shaking")
	app._show_commission()
	await create_timer(0.3).timeout
	verify(g.swings == 1,"Reading cannot advance observation")
	app._close_overlay()
	await Driver.perform(app,"mouse")
	verify(app.model.inspection_marks == [2] and fixed() == money,"Cup gesture commits one observation without revealing hidden grade: " + str([app.model.inspection_marks,g.active,g.swings,g.captured,g.paused,g.settling,app.application_focused,g.object_position,g.feedback,app.primary_touch]))
	verify(app.model.quality_report.contains("尚未") or app.model.stage == "inspection_work","Quality waits for complete inspection")

func stir_checks() -> void:
	await fixture("stir")
	var g = app.gesture_workshop
	var money := fixed()
	Driver.edge(app,g.object_position,true)
	Driver.move(app,g.PAN_CENTER)
	Driver.move(app,g.PAN_CENTER-Vector2(g.PAN_RADIUS.x,0))
	Driver.edge(app,g.object_position,false)
	verify(g.amount < 0.1 and app.model.roast_step == 1,"A straight jump across the pan is not stirring")
	# Resume with a deliberate counterclockwise circuit, with variable event density.
	await Driver.wait_ready(app,"touch")
	Driver.edge(app,g.object_position,true)
	var start: float = ((g.object_position-g.PAN_CENTER)/g.PAN_RADIUS).angle()
	for i in range(1,14):
		var angle := start-i*TAU/36.0
		Driver.move(app,g.PAN_CENTER+Vector2(cos(angle),sin(angle))*g.PAN_RADIUS)
		await process_frame
	Driver.edge(app,g.object_position,false)
	verify(g.progress() > 0.25 and g.progress() < 0.5,"Counterclockwise partial stirring is recognized")
	await capture("06_stirring")
	var progress: float = g.progress()
	app._show_help()
	await create_timer(0.3).timeout
	verify(is_equal_approx(g.progress(),progress),"Help freezes stirring progress")
	app._close_overlay()
	await Driver.perform(app)
	verify(app.model.roast_step == 2 and app.model.quality == 72 and fixed() == money,"Stirring alone cannot grant the whole roast gain: " + str([app.model.stage,app.model.roast_step,app.model.quality,g.active,g.amount,g.stir_direction,g.pointer_owner,fixed(),money]))
	# Finish the existing cooling performance through the UI.
	await tap("tool_2")
	await Driver.perform(app)
	verify(app.model.quality == 84 and app.model.stage == "remedy","Cooling retains the original 72 to 84 result")

func rope_checks() -> void:
	await fixture("rope")
	var g = app.gesture_workshop
	var money := fixed()
	var path: PackedVector2Array = g.rope_routes[0]
	for i in 6:
		Driver.edge(app,path[0],true)
		Driver.edge(app,path[0],false)
	verify(g.rope_point == 1,"Repeated clicks at rope start do not draw it")
	Driver.edge(app,path[-1],true)
	Driver.edge(app,path[-1],false)
	verify(g.rope_point == 1,"Clicking the rope endpoint cannot bypass the route")
	Driver.edge(app,path[0],true)
	Driver.move(app,path[-1])
	Driver.edge(app,path[-1],false)
	verify(not g.release_ready and app.model.packing_step == 2,"Straight shortcut cannot complete a bent rope")
	Driver.edge(app,path[g.rope_point-1],true)
	for i in range(g.rope_point,mini(12,path.size())): Driver.move(app,path[i])
	Driver.edge(app,path[11],false)
	verify(g.rope_point > 5 and app.model.packing_step == 2,"Fast valid strokes retain partial path progress")
	await capture("07_rope_tracing")
	app._show_history()
	var progress: float = g.progress()
	await create_timer(0.3).timeout
	verify(g.progress() == progress,"Original painting modal preserves rope progress")
	app._close_overlay()
	await Driver.perform(app)
	verify(app.model.stage == "packing_seal" and app.model.packing_step == 3,"Two valid rope releases finish the seal")
	verify(fixed() == money,"Rope retries never charge or improve cargo")
	await capture("08_seal_finished")
	# Finish a real UI trade with the gesture-based seal and all three loading rounds.
	await tap("choice_0")
	for i in 3: await Driver.perform(app,"mouse" if i%2 == 0 else "touch")
	verify(app.model.stage == "dock" and app.model.loaded_count() == 10,"Sealed trade passes all three draggable batches")
	await tap("choice_0")
	verify(app.model.stage == "voyage","Route still starts the original voyage")
	await tap("choice_1")
	await tap("choice_0")
	if app.model.stage == "acceptance": await tap("choice_0")
	verify(app.model.stage == "arrival","Actual voyage reaches delivery")
	await tap("choice_0")
	await tap("choice_0")
	verify(app.model.stage == "epilogue" and not app.model.result.is_empty(),"Gesture trade reaches its real story and settlement")
	await capture("09_gesture_trade_ending")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.logger.enabled = false
	capture_enabled = "--capture-gestures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	await loading_checks()
	await cup_checks()
	await stir_checks()
	await rope_checks()
	print("GESTURES_PASS: %d checks; real mouse/touch, three shapes, release validation, jitter, wrong drops, fast paths, modal/focus cancellation, no extra costs or RNG." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit()
