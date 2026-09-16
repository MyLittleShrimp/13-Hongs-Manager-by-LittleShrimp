extends "res://tests/test_gestures.gd"
## Regression traces use the real game viewport, including the legacy touch input guard.
var paint_count := 0

func capture(name: String) -> void:
	if not capture_enabled: return
	app.dialogue_clock = 1000
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.11.1/screens")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Capture smooth rope frame")

func stroke(points: Array, device: String, spacing: float) -> void:
	Driver.edge(app,points[0],true,device)
	for i in points.size()-1:
		await Driver.travel(app,points[i],points[i+1],device,maxi(1,ceili(points[i].distance_to(points[i+1])/spacing)))

func smooth_checks() -> void:
	await fixture("rope")
	var g = app.gesture_workshop
	var money := fixed()
	var start: Vector2 = g.rope_routes[0][0]
	var direction: Vector2 = (g.rope_routes[0][1]-start).normalized()
	await Driver.wait_ready(app,"mouse")
	Driver.edge(app,start,true,"mouse")
	var previous: Vector2 = g.rope_tip()
	for i in range(1,121):
		Driver.move(app,start+direction*i,"mouse")
		var current: Vector2 = g.rope_tip()
		verify(current.distance_to(previous) > 0.95 and current.distance_to(previous) < 1.05,"One-pixel mouse motion produces one-pixel rope motion, without waypoint jumps")
		previous = current
		await process_frame
	verify(g.rope_tip().distance_to(start+direction*120) < 0.1,"Visible rope end stays with the pointer")
	await capture("01_continuous_rope")
	Driver.edge(app,previous,false,"mouse")
	var progress: float = g.progress()
	Driver.move(app,start+direction*220,"mouse")
	verify(g.progress() == progress,"Hover after release cannot trace")
	app._show_help()
	Driver.edge(app,previous,true)
	Driver.move(app,start+direction*220)
	Driver.edge(app,start+direction*220,false)
	verify(g.progress() == progress,"Touches behind a modal cannot trace")
	app._close_overlay()
	await Driver.wait_ready(app,"touch")
	Driver.edge(app,previous+Vector2(0,28),true)
	verify(g.captured,"Resume can grab near the continuous tip with a finger offset")
	Driver.move(app,start+direction*155+Vector2(0,28))
	verify(g.progress() > progress,"Resumed offset movement advances immediately")
	progress = g.progress()
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Driver.edge(app,g.rope_tip(),false)
	verify(g.progress() == progress and not g.captured,"Losing focus preserves earned rope progress and cancels the contact")
	app._notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame
	await Driver.perform(app)
	verify(app.model.packing_step == 3 and fixed() == money,"Resumed ropes commit once without changing the economy")

func offset_checks() -> void:
	for offset in [-30.0,30.0]:
		await fixture("rope")
		var g = app.gesture_workshop
		var money := fixed()
		for route in 2:
			var corners: Array = [Vector2(807,528),Vector2(1124,584),Vector2(1121,703)] if route == 0 else [Vector2(981,496),Vector2(905,600),Vector2(902,691)]
			var first: Vector2 = (corners[1]-corners[0]).normalized()
			var second: Vector2 = (corners[2]-corners[1]).normalized()
			var n1: Vector2 = Vector2(-first.y,first.x)*offset
			var n2: Vector2 = Vector2(-second.y,second.x)*offset
			var join: Vector2 = (n1+n2)/(1.0+first.dot(second))
			var points := [corners[0]+n1,corners[1]+join,corners[2]+n2]
			await stroke(points,"touch",7.0 if offset < 0 else 90.0)
			verify(g.release_ready and app.model.packing_step == 2,"Both slow and sparse fast offset traces follow a bend without committing while held: "+str([offset,route,g.rope_distance,g.rope_lengths[route][-1],g.captured,g.feedback,g.last_pointer]))
			await capture("02_offset_"+str(int(offset))+"_route_"+str(route))
			Driver.edge(app,points[-1],false)
			await process_frame
			if route == 0: verify(g.rope_index == 1 and g.rope_distance == 0,"First release arms a fresh second rope")
		await create_timer(0.55).timeout
		verify(app.model.stage == "packing_seal" and fixed() == money,"Offset strokes finish both ropes without rerolling or spending")
	# A deliberately rounded corner, with only three motion samples on each route.
	await fixture("rope")
	var g = app.gesture_workshop
	for corners in [[Vector2(807,528),Vector2(1124,584),Vector2(1121,703)],[Vector2(981,496),Vector2(905,600),Vector2(902,691)]]:
		await Driver.wait_ready(app,"mouse")
		var first: Vector2 = (corners[1]-corners[0]).normalized()
		var second: Vector2 = (corners[2]-corners[1]).normalized()
		await stroke([corners[0],corners[1]-first*32,corners[1]+second*32,corners[2]],"mouse",1000.0)
		verify(g.release_ready,"Sparse events and a modestly rounded corner remain usable")
		Driver.edge(app,corners[2],false,"mouse")
		await process_frame
	await create_timer(0.55).timeout
	verify(app.model.packing_step == 3,"Fast rounded strokes still require both releases")

func boundary_checks() -> void:
	await fixture("rope")
	var g = app.gesture_workshop
	var path: PackedVector2Array = g.rope_routes[0]
	var money := fixed()
	for i in 8:
		Driver.edge(app,path[0]+Vector2(20,0),true)
		Driver.edge(app,path[0]+Vector2(20,0),false)
	verify(g.rope_distance == 0,"Repeated offset clicks cannot exploit the pickup tolerance")
	await stroke([path[0],path[-1]],"touch",1000.0)
	Driver.edge(app,path[-1],false)
	verify(not g.release_ready and g.rope_index == 0,"A direct diagonal cannot bypass the corner")
	var earned: float = g.rope_distance
	var tip: Vector2 = g.rope_tip()
	Driver.edge(app,path[-1],true)
	verify(not g.captured,"Far-ahead endpoint cannot resume an unfinished rope")
	Driver.edge(app,path[-1],false)
	Driver.edge(app,tip,true,"touch",0)
	Driver.edge(app,path[-1],true,"touch",1)
	Driver.move(app,path[-1],"touch",1)
	Driver.edge(app,path[-1],false,"touch",1)
	verify(g.rope_distance == earned and g.contact == 0,"Second finger cannot advance the rope")
	Driver.edge(app,tip,false,"touch",0,true)
	verify(not g.captured and g.rope_distance == earned,"Canceled contact preserves progress without completing")
	# Move away from the box, along an off-route detour, then try to rejoin near the end.
	Driver.edge(app,tip,true)
	Driver.move(app,tip+Vector2(0,-160))
	Driver.move(app,path[-1]+Vector2(160,-160))
	Driver.move(app,path[-1])
	Driver.edge(app,path[-1],false)
	verify(not g.release_ready and g.rope_distance < 200,"Off-route detour cannot teleport progress ahead")
	verify(fixed() == money,"All failed strokes preserve money, days, quality, RNG and ledger")
	await Driver.perform(app)
	verify(app.model.packing_step == 3,"A failed detour can be recovered by tracing from the saved tip")

func redraw_checks() -> void:
	if DisplayServer.get_name() == "headless": return
	await fixture("rope")
	var p = app.packing_effect
	p.draw.connect(func(): paint_count += 1)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	paint_count = 0
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	verify(paint_count == 0,"Static closed lid reuses draw commands over 60 frames")
	var g = app.gesture_workshop
	var start: Vector2 = g.rope_tip()
	Driver.edge(app,start,true)
	await Driver.travel(app,start,start+Vector2(170,30),"touch",20)
	Driver.edge(app,g.last_pointer,false)
	await RenderingServer.frame_post_draw
	verify(paint_count == 0 and g.rope_distance > 150,"Moving rope redraws independently of static lid")
	# An isolated packing layer confirms animation changes still invalidate its cache.
	var layer = load("res://scripts/packing_effect.gd").new()
	root.add_child(layer)
	layer.position = Vector2(-1000,-1000)
	layer.step = 1
	layer.performing = true
	layer.manual_fill = true
	layer.draw.connect(func(): paint_count += 1)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	paint_count = 0
	for i in range(1,11):
		layer.progress = i/10.0
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
	verify(paint_count == 10,"Ten changing tea-fill states draw ten fresh frames")
	layer.queue_free()
	await process_frame
	print("ROPE_DRAW_PASS: 0 static box rebuilds over 60 frames; independent rope movement; 10/10 changing fill states redrawn")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.logger.enabled = false
	capture_enabled = "--capture-rope" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	await smooth_checks()
	await offset_checks()
	await boundary_checks()
	await redraw_checks()
	print("ROPE_SMOOTHNESS_PASS: %d checks; continuous mouse/touch traces, offsets, sparse events, rounded corners, no shortcuts, pause/resume, one commit, unchanged economy." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit()
