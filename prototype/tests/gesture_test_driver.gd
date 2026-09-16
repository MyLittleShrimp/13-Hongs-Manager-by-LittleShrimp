extends RefCounted
## Test input only: inject real viewport pointer events, never call gesture completion.
static func edge(app, point: Vector2, pressed: bool, device: String = "touch", id: int = 0, canceled: bool = false) -> void:
	var event: InputEvent
	if device == "touch":
		event = InputEventScreenTouch.new()
		event.index = id
		event.canceled = canceled
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.global_position = point
	event.position = point
	event.pressed = pressed
	app.get_viewport().push_input(event,true)

static func move(app, point: Vector2, device: String = "touch", id: int = 0) -> void:
	var event: InputEvent
	if device == "touch":
		event = InputEventScreenDrag.new()
		event.index = id
	else:
		event = InputEventMouseMotion.new()
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	app.get_viewport().push_input(event,true)

static func wait_ready(app, device: String) -> void:
	if app.transition_guard > 0: await app.get_tree().create_timer(app.transition_guard+0.04).timeout
	if device == "mouse" and app.input_guard.last_touch_ms > Time.get_ticks_msec()-app.input_guard.suppression_ms:
		await app.get_tree().create_timer(app.input_guard.suppression_ms/1000.0+0.04).timeout
	await app.get_tree().process_frame

static func perform(app, device: String = "touch") -> void:
	await wait_ready(app,device)
	var g = app.gesture_workshop
	if not g.active: return
	match g.kind:
		"loading":
			var start: Vector2 = g.object_position + g.cells[0]*g.CELL + g.BOX_SIZE/2
			var end: Vector2 = start + g.target - g.object_position
			edge(app,start,true,device)
			for i in range(1,17):
				move(app,start.lerp(end,i/16.0),device)
				await app.get_tree().process_frame
			edge(app,end,false,device)
		"cup":
			edge(app,g.object_position,true,device)
			for side in [-1,1,-1,1]:
				move(app,g.CUP_CENTER+Vector2(side*122,0),device)
				await app.get_tree().process_frame
			edge(app,g.object_position,false,device)
		"stir":
			edge(app,g.object_position,true,device)
			var direction: float = g.stir_direction if g.stir_direction != 0 else 1
			var start: float = ((g.object_position-g.PAN_CENTER)/g.PAN_RADIUS).angle()
			for i in range(1,57):
				var angle := start+direction*i*TAU/52.0
				move(app,g.PAN_CENTER+Vector2(cos(angle),sin(angle))*g.PAN_RADIUS,device)
				await app.get_tree().process_frame
			edge(app,g.object_position,false,device)
		"rope":
			for route in range(g.rope_index,2):
				var path: PackedVector2Array = g.rope_routes[route]
				edge(app,path[g.rope_point-1],true,device)
				for i in range(g.rope_point,path.size()):
					move(app,path[i],device)
					await app.get_tree().process_frame
				edge(app,path[-1],false,device)
				await app.get_tree().process_frame
	await app.get_tree().create_timer(0.55).timeout
