extends RefCounted
## Presentation reads committed weather/event facts; never consumes economic RNG.
const PLACES := ["counter", "market", "inspection", "roasting", "packing", "dock", "vessel"]
const STATES := ["clear", "overcast", "storm"]
const ORIGINAL_STATE := {"counter":0, "market":0, "inspection":0, "roasting":0, "packing":2, "dock":1, "vessel":1}

static func state(t) -> int:
	if t.stage == "attract": return 0
	if t.cargo_event == "squall": return 2
	# A calm leg after a storm means a break in the rain, not guaranteed blue skies.
	if t.cargo_event == "clear": return mini(int(t.weather), 1)
	# A leaking hull alone does not change the sky.
	return clampi(int(t.weather), 0, 2)

static func texture_path(place: String, level: int) -> String:
	if int(ORIGINAL_STATE[place]) == level:
		return "res://assets/backgrounds/%s.png" % place
	return "res://assets/backgrounds/weather/%s_%s.png" % [place, STATES[level]]

static func caption(t) -> String:
	if t.cargo_event == "clear" and t.weather == 2: return "雨势暂歇 · 水路平稳"
	var sky: String = ["天色尚晴", "云低欲雨", "风雨正急"][state(t)]
	if t.stage == "voyage" and t.cargo_event == "leak": return sky + " · 舱底渗水"
	return "当前：" + sky

static func actor_tint(level: int) -> Color:
	return [Color.WHITE, Color(0.87, 0.90, 0.94), Color(0.74, 0.81, 0.88)][level]
