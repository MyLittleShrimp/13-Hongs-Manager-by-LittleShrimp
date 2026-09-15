extends SceneTree
var app
var checks := 0

func verify(value: bool, detail: String) -> void:
	checks += 1
	assert(value, detail)
	if not value: quit(1)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var player = app.music_player
	var instance: int = player.get_instance_id()
	verify(player.enabled and player.playing and player.track_index == 0, "Opening starts with Main Theme")
	verify(player.tracks.size() == 2, "Two user tracks loaded")
	verify(is_equal_approx(player.tracks[0].get_length(), 140.7) or absf(player.tracks[0].get_length() - 140.7) < 0.1, "Main Theme duration")
	verify(absf(player.tracks[1].get_length() - 148.35) < 0.1, "13 Hongs duration")
	verify(not player.tracks[0].loop and not player.tracks[1].loop, "Single-track loops disabled")
	player.seek(20)
	await create_timer(0.08).timeout
	app._show_character_picker()
	app._select_character(str(app.character_profiles[1].id))
	app._confirm_character()
	app._start()
	verify(app.model.stage == "intro" and app.overlay_kind == "", "Selected role starts directly")
	verify(player.get_playback_position() > 19, "Character selection and start do not restart opening theme")
	app._choose(0, "intro")
	app._choose(2, "contract")
	verify(app.current_location == "market" and player.get_playback_position() > 19, "Scene change keeps music position")
	verify(app.music_player.get_instance_id() == instance, "Only one persistent music player")
	for expected in [1, 0, 1]:
		player.seek(player.stream.get_length() - 0.15)
		var deadline := Time.get_ticks_msec() + 2500
		while player.track_index != expected and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		verify(player.track_index == expected and player.playing, "Actual MP3 end advances to expected track")
	player.seek(12)
	await create_timer(0.08).timeout
	await app._tour_tap("sound")
	verify(app.overlay_kind == "audio" and app.music_title_label.text.contains("13 Hongs"), "Sound panel displays current song")
	await app._tour_tap("music_toggle")
	verify(not player.enabled and player.stream_paused, "Music can be paused")
	var position: float = player.get_playback_position()
	await create_timer(0.2).timeout
	verify(absf(player.get_playback_position() - position) < 0.05, "Paused music does not progress")
	await app._tour_tap("effects_toggle")
	verify(app.ambient_enabled and not player.enabled, "Click effects are independent of background music")
	await app._tour_tap("music_toggle")
	verify(player.enabled and player.get_playback_position() >= position - 0.05, "Resume retains song and position")
	var slider: HSlider = app.overlay.find_child("MusicVolume", true, false)
	var center := slider.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = center
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	verify(player.volume_percent == 50, "Native touch sets music volume halfway")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(slider.size.x * 0.15, 0)
	root.push_input(drag, true)
	await process_frame
	verify(player.volume_percent == 65, "Native touch drag changes music volume")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = drag.position
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	await app._tour_tap("close_help")
	app._end_session("replay")
	app._start()
	verify(app.music_player.get_instance_id() == instance and player.track_index == 1, "Replay keeps playlist going")
	app._end_session("completed")
	verify(player.track_index == 1 and player.playing, "Returning to title does not interrupt playlist")
	if "--capture-music" in OS.get_cmdline_user_args():
		app._show_audio_settings()
		await create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var folder := ProjectSettings.globalize_path("res://../artifacts/audio")
		DirAccess.make_dir_recursive_absolute(folder)
		verify(root.get_texture().get_image().save_png(folder.path_join("sound-settings.png")) == OK, "Sound panel screenshot")
	print("MUSIC_PASS: %d checks; real MP3 endings 0→1→0→1, scene continuity, pause/resume, independent effects and replay." % checks)
	app.queue_free()
	# Allow the audio mixer to release its final playback reference before exit.
	await create_timer(0.3).timeout
	quit(0)
