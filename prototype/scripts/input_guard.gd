extends RefCounted
## Some Windows touch drivers also emit a mouse click for the same contact.
var suppression_ms := 900
var last_touch_ms := -10000
var last_touch_position := Vector2(-10000, -10000)
var source := ""
var position := Vector2.ZERO
var last_source := ""
var last_position := Vector2(-10000, -10000)
var last_activation_ms := -10000
var last_button := 0
var reason := ""

func mouse_wait_ms(point: Vector2) -> int:
	if point.distance_to(last_touch_position) > 96: return 0
	return maxi(0, suppression_ms - (Time.get_ticks_msec() - last_touch_ms))

func filter_event(event: InputEvent) -> bool:
	reason = ""
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_touch_ms = Time.get_ticks_msec()
		last_touch_position = event.position
		source = "touch"
		position = event.position
	elif event is InputEventMouse:
		if mouse_wait_ms(event.position) > 0:
			reason = "mouse_after_touch"
			return true
		source = "mouse"
		position = event.position
	return false

func allow_activation(button: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - last_activation_ms < suppression_ms and source != last_source and position.distance_to(last_position) < 96:
		reason = "same_contact_two_sources"
		return false
	if button == last_button and now - last_activation_ms < 300:
		reason = "button_bounce"
		return false
	last_activation_ms = now
	last_button = button
	last_source = source
	last_position = position
	return true
