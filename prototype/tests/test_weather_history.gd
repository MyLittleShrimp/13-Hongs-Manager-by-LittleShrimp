extends SceneTree
const Weather = preload("res://scripts/weather_scene.gd")
var app
var checks := 0
var capture_enabled := false

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		push_error(detail)
		quit(1)
		assert(false, detail)

func _initialize() -> void:
	call_deferred("run")

func layout(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			check(child.size.x <= box.size.x + 2 and child.size.y <= box.size.y + 2, "History text fits: " + str(child.name))
		layout(child)

func snapshot() -> Array:
	return [app.model.cash, app.model.ticks, app.model.rng.state, app.model.revision, app.model.ledger.duplicate(true)]

func capture(filename: String) -> void:
	if not capture_enabled: return
	app.dialogue_clock = 1000
	await create_timer(0.85).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.8/screens")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(filename + ".png")) == OK, "Engine screenshot saved")

func tap(id: String) -> void:
	await app._tour_tap(id)
	await process_frame

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.logger.enabled = false
	capture_enabled = "--capture-weather-history" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	app.model.reset(1)
	app.model.start()
	for choice in [0, 2, 0, 0, 0, 0]: check(app.model.choose(choice), "Legal purchase fixture")
	app.model.packaging = app.model.data.packing[1].duplicate(true)
	app.model.route = app.model.data.routes[0].duplicate(true)
	var stages := ["intro", "market", "inspection", "roast_plan", "packing", "dock", "voyage"]
	var paths := {}
	for i in stages.size():
		app.model.stage = stages[i]
		app.model.cargo_event = "leak" if stages[i] == "voyage" else ""
		var place: String = Weather.PLACES[i]
		check(app.model.location() == place, "Fixture visits " + place)
		for sky in 3:
			app.model.weather = sky
			var before := snapshot()
			app._render()
			await process_frame
			var path: String = Weather.texture_path(place, sky)
			paths[path] = true
			check(app.background.texture != null and app.background.texture.resource_path == path, "Rendered background matches " + place + str(sky))
			check(app.atmosphere.wet == (sky == 2), "Rain matches committed sky")
			check(app.page.get_node("WeatherCaption").text.contains(["天色尚晴", "云低欲雨", "风雨正急"][sky]), "Header describes actual background")
			check(snapshot() == before, "Weather redraw never consumes money, time or economic RNG")
			if place in ["market", "packing", "vessel"]: await capture(place + "_" + str(sky))
		check(app.ui_buttons.has("scene_art"), "Every game scene provides the art entry")
		var before := snapshot()
		await tap("scene_art")
		check(app.overlay_kind == "history", "Touch opens history")
		var art = app.overlay.find_child("HistoryArtwork", true, false)
		var entry: Dictionary = app.history_catalog.scenes[place]
		var record: Dictionary = app.history_catalog.artworks[entry.artwork]
		check(art != null and art.texture != null and art.texture.resource_path == record.image, "Matching local historical image: " + place)
		check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Entire original remains uncropped")
		layout(app.overlay)
		if place in ["counter", "inspection", "roasting", "packing"]: await capture("history_" + place)
		var stage: String = app.model.stage
		app._choose(0, stage, app.model.revision)
		check(app.model.stage == stage and snapshot() == before, "Reading blocks underlying trade actions")
		var normal_height: float = art.size.y
		await tap("history_zoom")
		art = app.overlay.find_child("HistoryArtwork", true, false)
		check(art != null and art.size.y > normal_height * 1.25, "Zoom increases available picture height")
		layout(app.overlay)
		if place == "inspection": await capture("history_zoom")
		await tap("history_back")
		await tap("history_source")
		layout(app.overlay)
		if place == "counter": await capture("history_source")
		await tap("history_back")
		await tap("close_help")
		check(app.overlay_kind == "" and snapshot() == before, "Return keeps the same trade and RNG")
	check(paths.size() == 21, "Seven locations have three distinct offline backgrounds each")
	app.model.stage = "voyage"
	app.model.weather = 0
	app.model.cargo_event = "squall"
	app._render()
	check(app.current_weather == 2 and app.atmosphere.wet, "Squall replaces a sunny voyage with rain")
	await capture("voyage_squall")
	app.model.weather = 2
	app.model.cargo_event = "clear"
	app._render()
	check(app.current_weather == 1 and not app.atmosphere.wet and Weather.caption(app.model).contains("雨势暂歇"), "Calm leg clears rain but retains cloud")
	app.model.weather = 0
	app.model.cargo_event = "leak"
	app._render()
	check(app.current_weather == 0 and not app.atmosphere.wet, "Hull leak alone does not summon a storm")
	for place in ["counter", "inspection", "roasting", "packing"]:
		app.atmosphere.place = place
		check(not app.atmosphere.exposed(Vector2(960, 780)), "No rain on indoor worktable or floor: " + place)
	app.model.reset(1)
	app._render()
	check(app.current_weather == 0 and not app.atmosphere.wet, "Next title screen resets the previous storm")
	await create_timer(0.8).timeout
	check(not app.previous_background.visible, "Weather transition leaves no stale overlay")
	print("WEATHER_HISTORY_PASS: %d checks; 21 backgrounds, event/sky consistency, offline originals, native touch modals, unchanged economy." % checks)
	app.queue_free()
	# Let the audio thread release its final MP3 playback reference.
	await create_timer(0.3).timeout
	quit()
