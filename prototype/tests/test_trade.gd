extends SceneTree
const Trade = preload("res://scripts/trade_session.gd")
var config: Dictionary
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(false, message)

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/trade_v2.json"))
	call_deferred("run")

func act(t, index: int) -> void:
	if t.stage in ["packing_work", "roasting_work"]:
		verify(t.select_tool(t.packing_step if t.stage == "packing_work" else t.roast_step, t.revision), "Take correct tool")
	var ticket: int = t.revision
	var stage: String = t.stage
	verify(t.choose(index, stage, ticket), "Action succeeds: " + stage)
	var balance: int = t.cash
	var random_state: int = t.rng.state
	verify(not t.choose(index, stage, ticket), "Same callback is idempotent even within remedy")
	verify(t.cash == balance and t.rng.state == random_state, "Duplicate does not spend or reroll")
	if stage == "bargain":
		act(t, 0)
		act(t, 0)
	if t.stage == "inspection_work" and stage == "inspection":
		for i in t.inspection_level + 1: act(t, i)
		verify(t.finish_inspection(t.revision), "Confirm observed inspection")
	if t.stage == "roast_plan" and stage == "remedy":
		act(t, 0)
		for i in 3: act(t, 0)
	if t.stage == "voyage_report" and stage == "voyage": act(t, 0)
	if t.stage == "packing_seal" and stage == "packing_work": act(t, 0)

func purchased(seed_value: int = 121):
	var t = Trade.new(config)
	t.reset(seed_value)
	t.start()
	for choice in [0, 2, 0, 0]: act(t, choice)
	return t

func complete(t, strategy: Array) -> void:
	var steps := 0
	var remedy_visits := 0
	while t.stage != "result" and steps < 40:
		steps += 1
		if t.stage == "packing_work":
			act(t, 0)
			continue
		var choice := 0
		match t.stage:
			"intro": choice = 0
			"contract": choice = strategy[0]
			"market": choice = strategy[1]
			"bargain": choice = strategy[2]
			"inspection": choice = strategy[3]
			"remedy":
				choice = strategy[4] if remedy_visits < int(strategy[8]) else 0
				remedy_visits += 1
			"shipment_review": choice = 1
			"packing": choice = strategy[5]
			"packing_work": choice = 0
			"dock": choice = strategy[6]
			"voyage": choice = strategy[7]
			"acceptance": choice = strategy[9]
			"arrival": choice = 0
		if not t.available(choice):
			if t.can_borrow() and bool(strategy[10]):
				verify(t.borrow(t.revision), "One rescue loan")
				continue
			if t.stage in ["packing", "dock"]:
				verify(t.use_deferred(t.revision), "Zero cash can use deferred expense")
				continue
			for fallback in 3:
				if t.available(fallback):
					choice = fallback
					break
		act(t, choice)
	verify(t.stage == "result", "Every legal strategy reaches result")
	check_ledger(t)

func check_ledger(t) -> void:
	var balance := int(config.initial_cash)
	var ids := {}
	for row in t.ledger:
		verify(not ids.has(row.action), "Unique transaction")
		ids[row.action] = true
		balance += int(row.amount)
		verify(balance == int(row.balance), "Each balance is conserved")
	verify(balance == t.cash, "Ledger closes")
	verify(t.cash == int(config.initial_cash) + int(t.result.profit), "Borrowing is not profit")
	verify(t.result.profit == t.result.due - t.result.cost, "Operating profit identity")
	verify(t.result.balance_due == t.result.due - config.deposit, "Prepayment counted once")
	verify(t.result.delivered + t.result.lost == 10, "Physical cargo conserved")
	verify(t.result.qualified == (t.result.delivered if t.result.quality_met else 0), "Qualified distinct from delivered")
	verify(t.result.contract_met == (t.result.mode == "standard" and t.result.quality_met and t.result.delivered == 10 and t.result.late == 0), "Fulfillment is independent of profit")
	verify(t.debt_due() == 0 and t.debt_settled, "All obligations accounted at settlement")
	verify(t.result.debt_settlement == t.loan_principal + t.loan_fee + t.deferred_cost, "Principal, fee, deferred costs paid exactly once")

func run() -> void:
	# The visitor's exact issue: known 72 -> 84 -> 96, with no forced exit from workshop.
	var t = purchased()
	t.quality = 72
	act(t, 2)
	var cash_before: int = t.cash
	var ticks_before: int = t.ticks
	var random_before: int = t.rng.state
	act(t, 1)
	verify(t.quality == 84 and t.stage == "remedy", "First processing leaves room to decide")
	verify("差2" in t.quality_guidance(), "84/86 explicitly communicates the gap")
	verify("96" in t.remedy_preview(12), "Next treatment preview")
	act(t, 1)
	verify(t.quality == 96 and t.cash == cash_before - 40 and t.ticks == ticks_before + 4, "Second processing costs money/time and improves quality")
	verify(not t.available(1) and not t.choose(1), "No unlimited third processing")
	verify(t.rng.state == random_before, "Processing does not reroll initial quality")
	var ticket: int = t.revision
	verify(t.borrow(ticket), "Rescue loan offered")
	verify(t.cash == cash_before + 20 and t.debt_due() == 66, "Cash +60, debt +66")
	verify(not t.borrow(ticket) and not t.borrow(), "Loan available only once")
	complete(t, [2,0,0,2,0,1,1,1,0,0,1])

	# Known bad quality: player can return for treatment without rerolling.
	t = purchased()
	t.quality = 72
	act(t, 2)
	act(t, 1)
	var state: int = t.rng.state
	var balance: int = t.cash
	act(t, 0)
	verify(t.stage == "shipment_review", "Underspec cargo requires warning")
	act(t, 0)
	verify(t.stage == "remedy" and t.quality == 84 and t.cash == balance and t.rng.state == state, "Returning is free and does not erase costs or reroll")
	act(t, 0)
	act(t, 1)
	verify(t.stage == "packing", "Can knowingly proceed with risk")

	# 84-quality delivery is a proposal, never automatic full compliance or auto-payment.
	t = purchased()
	t.stage = "acceptance"
	t._book("test_prior_services", "测试既有处理与运费", -(215 - (int(config.initial_cash) + int(config.deposit) - t.cash)))
	t.pending_delivery = {"delivered":10,"lost":0,"quality":84,"quality_met":false,"quality_rate":0.964,
		"gross":289,"late":0,"penalty":0,"due":289,"risk":0.1,"damaged":false,"ticks":10,"resale_gross":132}
	balance = t.cash
	verify(t.result.is_empty() and not t.committed.has("settlement"), "Proposal has not paid yet")
	state = t.rng.state
	act(t, 0)
	verify(t.result.due == 289 and not t.result.contract_met and t.result.qualified == 0, "84/86 can be sold only as explicitly discounted cargo")
	verify(t.cash == balance + 229 and t.rng.state == state, "Accepted quote books once, no negotiation reroll")
	verify(t.result.profit == 74 and t.cash == 234, "Visitor screenshot accounting reproduced without implying compliance")
	check_ledger(t)

	# Zero-cash scenario, after prior expenses and even with the only loan already spent.
	t = purchased(9)
	verify(t.borrow(), "Borrow before hardship")
	t._book("test_prior_expense", "测试前序开支", -t.cash)
	verify(t.cash == 0, "Zero cash fixture")
	act(t, 0)
	act(t, 0)
	if t.stage == "shipment_review": act(t, 1)
	verify(t.stage == "packing" and t.cash == 0, "Zero-cost inspection/continue avoid a dead end")
	ticket = t.revision
	verify(t.use_deferred(ticket), "Old chest needs no cash now")
	verify(not t.use_deferred(ticket), "Deferred packing cannot be duplicated")
	for i in 3: act(t, 0)
	verify(t.use_deferred(t.revision), "Deferred freight works with loan already consumed")
	verify(t.cash == 0 and t.debt_due() == 96, "66 loan +12 packing +18 freight")
	act(t, 1)
	if t.stage == "acceptance": act(t, 1)
	act(t, 0)
	verify(t.stage == "result", "Cash exhaustion still completes the trade")
	check_ledger(t)
	verify(t.result.cost >= 36, "Fees and deferred costs are not free")
	t.reset(20)
	verify(t.rework_count == 0 and not t.exchange_used and t.loan_principal == 0 and t.deferred_cost == 0 and t.pending_delivery.is_empty(), "Reset clears remedies, debts and offer")

	var rng := RandomNumberGenerator.new()
	rng.seed = 81322
	var wins := 0
	var losses := 0
	var discounted := 0
	var resold := 0
	var debts := 0
	var outcomes := {}
	for seed_value in 3000:
		var strategy: Array = []
		for i in 9: strategy.append(rng.randi_range(0,2))
		strategy[7] = rng.randi_range(0,1)
		strategy.append(rng.randi_range(0,1))
		strategy.append(rng.randi_range(0,1))
		var sim = Trade.new(config)
		sim.reset(seed_value)
		sim.start()
		complete(sim, strategy)
		if sim.result.profit > 0: wins += 1
		if sim.result.profit < 0: losses += 1
		if sim.result.mode == "discount": discounted += 1
		if sim.result.mode == "resale": resold += 1
		if sim.result.debt_settlement > 0: debts += 1
		outcomes[sim.result.profit] = true
	verify(wins > 0 and losses > 0 and outcomes.size() > 100, "Still real random profits and losses")
	verify(discounted > 0 and resold > 0 and debts > 0, "New branches exercised")
	var a = Trade.new(config)
	var b = Trade.new(config)
	for sim in [a,b]:
		sim.reset(728)
		sim.start()
		complete(sim, [2,1,1,2,1,1,1,1,2,0,1])
	verify(a.result == b.result, "Same seed/actions including debt reproduce")
	var report := {"runs":3000,"wins":wins,"losses":losses,"flat":3000-wins-losses,"discounted":discounted,"resold":resold,"debt_runs":debts,"distinct_profits":outcomes.size(),"checks":checks}
	var file := FileAccess.open("res://../artifacts/v0.4/economy_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("V4_RULES_PASS ", JSON.stringify(report))
	quit(0)
