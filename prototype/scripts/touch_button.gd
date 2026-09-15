extends Button
## Mouse uses Button's native release activation. Native touch has one explicit path.
var captured_touch := -1

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE

func _gui_input(event: InputEvent) -> void:
	if disabled:
		captured_touch = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and captured_touch == -1:
			captured_touch = event.index
			accept_event()
		elif not event.pressed and event.index == captured_touch:
			captured_touch = -1
			accept_event()
			if not event.canceled and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
	elif event is InputEventScreenDrag and event.index == captured_touch:
		accept_event()

func cancel_touch() -> void:
	captured_touch = -1
