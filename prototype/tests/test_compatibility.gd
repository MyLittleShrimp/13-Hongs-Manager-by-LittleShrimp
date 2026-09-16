extends SceneTree
var app
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false, message)

func _initialize() -> void:
	call_deferred("run")

func raw(point: Vector2, source: String, down: bool) -> void:
	var event: InputEvent
	if source == "touch":
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.global_position = point
	event.position = point
	event.pressed = down
	root.push_input(event, true)

func click(point: Vector2, source: String) -> void:
	raw(point, source, true)
	await process_frame
	raw(point, source, false)
	await process_frame
	await process_frame

func result_fixture() -> void:
	app._end_session("test")
	app.model.reset(121)
	app.model.start()
	var steps := 0
	while app.model.stage != "result" and steps < 100:
		if app.model.stage == "packing_work": app.model.select_tool(app.model.packing_step)
		verify(app.model.choose(1 if app.model.stage == "shipment_review" else 0), "Legal result fixture")
		steps += 1
	verify(app.model.stage == "result", "Fixture reaches settlement")
	app._render()
	await create_timer(1.1).timeout

func capture(name: String) -> void:
	if "--capture-compat" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.7.1")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "Save real compatibility screen")

func mixed_music(first: String, second: String, delay: float) -> void:
	await create_timer(1.35).timeout
	app.music_player.set_enabled(true)
	app._show_audio_settings()
	var point: Vector2 = app.ui_buttons.music_toggle.get_global_rect().get_center()
	await click(point, first)
	await create_timer(delay).timeout
	await click(point, second)
	verify(not app.music_player.enabled and app.ui_buttons.music_toggle.text.contains("关"), "Mixed input toggles once: " + first + " -> " + second)
	verify(app.music_player.stream_paused and app.music_player.volume_linear == 0, "Pause and zero output agree")
	verify(AudioServer.is_bus_mute(app.music_player.music_bus), "Music bus is independently muted")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = false
	app.logger.enabled = false
	await create_timer(1.3).timeout
	app._show_audio_settings()
	var point: Vector2 = app.ui_buttons.music_toggle.get_global_rect().get_center()
	await click(point, "touch")
	await click(point, "mouse")
	print("REPRO mixed touch+mouse: music_enabled=", app.music_player.enabled)
	var music_bug: bool = app.music_player.enabled
	await result_fixture()
	point = app.ui_buttons.choice_0.get_global_rect().get_center()
	await click(point, "touch")
	await click(point, "mouse")
	print("REPRO mixed touch+mouse: closing_stage=", app.model.stage)
	if "--repro-only" not in OS.get_cmdline_user_args():
		verify(not music_bug, "A touch followed by synthetic mouse must leave music disabled")
		verify(app.model.stage == "epilogue", "Closing dialogue must not fall through to ending the session")
		await click(point, "touch")
		verify(app.model.stage == "epilogue", "Immediate repeated touch cannot skip the closing page")
		await create_timer(1.35).timeout
		await capture("closing-remains-open")
		await click(point, "touch")
		verify(app.model.stage == "attract", "A later intentional finish still works")
		for delay in [0.0, 0.3, 0.7]: await mixed_music("touch", "mouse", delay)
		if app.compatibility_mode: await mixed_music("touch", "mouse", 1.05)
		for delay in [0.0, 0.3]: await mixed_music("mouse", "touch", delay)
		await create_timer(1.35).timeout
		app.music_player.set_enabled(true)
		app._show_audio_settings()
		point = app.ui_buttons.music_toggle.get_global_rect().get_center()
		raw(point, "mouse", true)
		raw(point, "touch", true)
		await process_frame
		raw(point, "touch", false)
		raw(point, "mouse", false)
		await process_frame
		verify(not app.music_player.enabled, "Interleaved mouse/touch edges toggle only once")
		await capture("music-stays-off")
		var paused_at: float = app.music_player.get_playback_position()
		app.music_player.set_volume_percent(65)
		await create_timer(0.2).timeout
		verify(absf(app.music_player.get_playback_position() - paused_at) < 0.05, "Disabled song retains position")
		verify(app.music_player.volume_linear == 0 and AudioServer.is_bus_mute(app.music_player.music_bus), "Changing volume cannot unmute disabled music")
		# Enable real output logic while keeping automated audio on the Dummy device.
		app.music_player.output_suppressed = false
		await create_timer(1.35).timeout
		await click(point, "mouse")
		verify(app.music_player.enabled and not app.music_player.stream_paused, "Deliberate mouse toggle resumes playback")
		verify(not AudioServer.is_bus_mute(app.music_player.music_bus) and is_equal_approx(app.music_player.volume_linear, 0.65), "Resume restores selected volume")
		await create_timer(1.35).timeout
		raw(point, "touch", true)
		var canceled := InputEventScreenTouch.new()
		canceled.index = 0
		canceled.position = point
		canceled.canceled = true
		root.push_input(canceled, true)
		await process_frame
		verify(app.music_player.enabled, "Canceled touch does not toggle music")
		await click(point, "touch")
		await click(point, "touch")
		verify(not app.music_player.enabled, "Contact bounce does not toggle twice")
		await result_fixture()
		point = app.ui_buttons.choice_0.get_global_rect().get_center()
		await click(point, "mouse")
		await click(point, "touch")
		verify(app.model.stage == "epilogue", "Reverse event order cannot skip the closing page")
		await create_timer(1.35).timeout
		await click(app.ui_buttons.again.get_global_rect().get_center(), "mouse")
		verify(app.model.stage == "intro", "Intentional replay still starts a new trade")
		print("COMPATIBILITY_PASS: %d checks" % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit(0)
