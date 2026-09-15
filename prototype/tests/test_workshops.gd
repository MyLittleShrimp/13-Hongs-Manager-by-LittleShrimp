extends SceneTree
const Trade = preload("res://scripts/trade_session.gd")
var config: Dictionary
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(false, message)

func purchased(seed_value: int = 121):
	var t = Trade.new(config)
	t.reset(seed_value)
	t.start()
	for i in [0,2,0,0]: verify(t.choose(i), "Reach purchased tea")
	for i in 2: verify(t.choose(0), "Complete merchant exchange")
	t.quality = 72
	return t

func inspect_all(t) -> void:
	verify(t.choose(2), "Pay for full inspection")
	for i in 3: verify(t.choose(i), "Read inspection clue")
	verify(t.finish_inspection(t.revision), "Confirm inspection")

func run_roast(t, heat: int) -> void:
	verify(t.choose(1), "Enter roasting room")
	verify(t.choose(heat), "Select fire plan")
	for i in 3:
		var ticket: int = t.revision
		var money: int = t.cash
		var random_state: int = t.rng.state
		verify(not t.choose(0), "Cannot act without tool")
		verify(not t.select_tool((i+1)%3, ticket), "Wrong tool does not advance")
		verify(t.select_tool(i, ticket), "Select correct tool")
		verify(not t.choose(0, "roasting_work", ticket), "Old action ticket after tool is rejected")
		verify(not t.select_tool(i), "Repeated tool selection is inert")
		verify(t.choose(0, "roasting_work", t.revision), "Use tool")
		verify(t.cash == money and t.rng.state == random_state, "Manual action is not another charge or reroll")

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/trade_v2.json"))
	call_deferred("run")

func run() -> void:
	for level in [1,2]:
		var t = purchased()
		var before: int = t.cash
		verify(t.choose(level), "Start inspection")
		verify(t.inspected == 0 and t.stage == "inspection_work", "Exact grade withheld until confirmation")
		verify(t.cash == before - (8 if level == 1 else 18), "Inspection fee charged once")
		verify(not t.finish_inspection(), "Cannot finish without observations")
		for i in level + 1:
			verify(t.choose(i), "Distinct observations accepted")
			var revision: int = t.revision
			verify(not t.choose(i) and t.revision == revision, "Same observation cannot satisfy another requirement")
		verify(t.finish_inspection(), "Observed items unlock completion")
		verify(t.inspected == level and t.stage == "remedy", "Requested confidence retained")
		verify(not t.finish_inspection(), "Cannot reconfirm inspection")
	for heat in 3:
		var t = purchased()
		inspect_all(t)
		var before: int = t.cash
		var time_before: int = t.ticks
		run_roast(t, heat)
		verify(t.quality == 72 + int(Trade.ROAST_PLANS[heat].gain), "Fire plan controls quality gain")
		verify(t.cash == before - int(Trade.ROAST_PLANS[heat].cost), "Fire plan charge is exact")
		verify(t.ticks == time_before + int(Trade.ROAST_PLANS[heat].ticks), "Fire plan time is exact")
		verify(t.rework_count == 1 and t.stage == "remedy", "Returns to remedy after actual work")
	var t = purchased()
	inspect_all(t)
	var before: int = t.cash
	var random_state: int = t.rng.state
	verify(t.choose(1), "Preview workshop")
	verify(t.cancel_roast_plan(), "Can leave before paying")
	verify(t.cash == before and t.rework_count == 0 and t.rng.state == random_state, "Preview/cancel cannot reroll or spend")
	run_roast(t, 0)
	run_roast(t, 0)
	verify(t.quality == 96 and not t.available(1), "Known 72 to84 to96 path and cap preserved")
	verify(t.choose(0), "Proceed to packing")
	verify(t.choose(0), "Buy packing")
	for i in 3:
		verify(not t.choose(0), "Packing needs material first")
		verify(t.select_tool(i), "Take packing material")
		verify(t.choose(0), "Pack one layer")
	verify(t.stage == "packing_seal", "Seal is visible before leaving scene")
	verify(t.choose(0) and t.stage == "dock", "Carry sealed cargo to dock")
	verify(t.choose(0), "Sail")
	verify(t.choose(1), "Resolve voyage once")
	verify(t.stage == "voyage_report" and t.result.is_empty() and not t.committed.has("settlement"), "Onboard report precedes settlement")
	var pending: Dictionary = t.pending_delivery.duplicate(true)
	var state: int = t.rng.state
	verify(t.choose(0), "Meet buyer")
	verify(t.pending_delivery == pending and t.rng.state == state, "Going ashore cannot reroll damage")
	if t.stage == "acceptance": verify(t.choose(0), "Explicitly agree undergrade quote")
	verify(t.stage == "arrival" and not t.result.is_empty(), "Trade settles after visible report")
	verify(t.ending().size() == 3, "Outcome drives ending")
	for mode in ["standard", "discount", "resale"]:
		t.result.mode = mode
		for gap in [0, 20]:
			t.result.funding_gap = gap
			verify(not t.ending()[1].is_empty(), "All settlement modes have a story")
	t.result = {"mode":"standard", "funding_gap":0, "profit":0, "contract_met":true, "lost":0, "late":0, "quality_met":true, "delivered":10}
	verify("收支相抵" in t.ending()[1] and not "蚀" in t.ending()[0], "Break-even delivery must not be narrated as a loss")
	t.reset(3)
	verify(t.work_tool == -1 and t.roast_plan.is_empty() and t.inspection_marks.is_empty(), "Reset clears station state")
	print("V4_WORKSHOP_RULES_PASS: %d checks; observation, fire plans, tools, no rerolls, seals, arrival, endings." % checks)
	quit(0)
