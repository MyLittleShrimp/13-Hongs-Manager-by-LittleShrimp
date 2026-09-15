extends SceneTree
## Selection is cosmetic: preserve the complete trade and its random state.
var app
var checks := 0
var capture_enabled := false

func verify(value: bool, detail: String) -> void:
	checks += 1
	assert(value, detail)
	if not value: quit(1)

func _initialize() -> void:
	call_deferred("run")

func tap(id: String, native_touch: bool = true) -> void:
	var before: String = app.model.stage
	await app._tour_tap(id, native_touch)
	if before == "bargain" and app.model.stage == "bargain_result":
		for i in 2: await app._tour_tap("choice_0", native_touch)

func snapshot() -> Dictionary:
	var state := {}
	for property in app.model.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = app.model.get(property.name)
			if not value is Object: state[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	state["random_state"] = app.model.rng.state
	return state

func check_layout(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta("layout_box"):
			var box: Rect2 = child.get_meta("layout_box")
			verify(child.size.x <= box.size.x + 2 and child.size.y <= box.size.y + 2, "Character UI fits " + child.name)
		check_layout(child)

func capture(name: String) -> void:
	if not capture_enabled: return
	await create_timer(0.95).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://../artifacts/v0.5-start")
	DirAccess.make_dir_recursive_absolute(folder)
	verify(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "Save GPU capture")

func switch_to(index: int) -> void:
	var before := snapshot()
	await tap("avatar")
	verify(app.overlay_kind == "avatar", "Role switch visible during " + app.model.stage)
	await tap("character_%d" % index)
	await process_frame
	check_layout(app.overlay)
	await tap("confirm_character")
	verify(snapshot() == before, "Switch preserves all trade fields and RNG in " + app.model.stage)
	verify(app.player_actor.profile.id == app.character_profiles[index].id, "Active actor receives chosen role")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.logger.enabled = false
	capture_enabled = "--capture-characters" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	app.model.reset(3)
	app._render()
	await capture("00_title_male")
	await tap("avatar")
	verify(app.model.stage == "attract" and app.overlay_kind == "avatar", "Only title avatar button opens selection")
	var before := snapshot()
	await tap("character_1")
	verify(app.avatar_profile.display_name == "阿砚", "Preview does not commit role")
	verify(snapshot() == before, "Selecting role does not reroll market")
	await capture("01_character_selection")
	await tap("close_help")
	verify(app.avatar_profile.display_name == "阿砚" and app.model.stage == "attract", "Cancel keeps previous role and stays at title")
	await switch_to(1)
	await switch_to(0)
	await tap("avatar", false)
	await tap("character_1", false)
	await tap("confirm_character", false)
	verify(app.model.stage == "attract" and app.overlay_kind == "" and app.avatar_profile.display_name == "阿宁", "Confirm role returns to title without starting")
	await capture("01_title_female")
	await tap("start", false)
	verify(app.model.stage == "intro" and app.overlay_kind == "" and app.avatar_profile.display_name == "阿宁", "Start enters story directly with current role")
	verify(not app.ui_buttons.has("avatar"), "No role switch in the active game")
	app._show_character_picker()
	verify(app.overlay_kind == "", "Role picker cannot reopen during gameplay")
	verify(str(app._story()[1]).begins_with("阿宁，"), "Opening dialogue addresses selected woman")
	await capture("02_female_intro")
	for i in [0,2,0,0]: await tap("choice_%d" % i)
	verify(app.model.stage == "inspection", "Female reaches purchased tea")
	await tap("choice_2")
	for i in 3: await tap("observe_%d" % i)
	await tap("inspection_done")
	verify(app._story()[0] == "阿宁", "Player dialogue uses selected name")
	await tap("choice_1")
	await tap("choice_0")
	await tap("tool_0")
	verify(not app.ui_buttons.work_action.disabled, "Selected tool remains usable")
	await capture("03_female_roasting")
	await tap("work_action")
	for i in [1,2]:
		await tap("tool_%d" % i)
		await tap("work_action")
	await tap("choice_0")
	if app.model.stage == "shipment_review": await tap("choice_1")
	await tap("choice_1")
	for i in 3:
		await tap("tool_%d" % i)
		await tap("pack_action")
	await capture("04_female_packing")
	await tap("choice_0")
	await tap("choice_1")
	await capture("05_female_voyage")
	await tap("choice_1")
	await tap("choice_0")
	if app.model.stage == "acceptance": await tap("choice_0")
	await tap("choice_0")
	verify(app.model.stage == "result" and app.avatar_profile.display_name == "阿宁", "Female completes whole trade")
	await capture("06_female_result")
	await tap("choice_0")
	verify(app.model.stage == "epilogue", "Female reaches ending")
	await capture("07_female_epilogue")
	await tap("again")
	verify(app.model.stage == "intro" and app.avatar_profile.display_name == "阿宁", "Replay preserves chosen role")
	await tap("exit")
	await tap("confirm_exit")
	verify(app.model.stage == "attract" and app.avatar_profile.display_name == "阿砚", "End resets role for next visitor")
	await tap("start")
	verify(app.model.stage == "intro" and app.overlay_kind == "" and app.avatar_profile.display_name == "阿砚", "Default male starts directly without opening role picker")
	print("V5_CHARACTER_PASS: %d checks; title-only selection, direct start, preview/cancel, touch/mouse, whole female run, RNG, replay and reset." % checks)
	app.queue_free()
	await create_timer(0.3).timeout
	quit(0)
