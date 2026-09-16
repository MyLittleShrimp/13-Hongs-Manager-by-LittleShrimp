extends RefCounted
## Seeded economy. UI never draws randomness or books money.
var data: Dictionary
var rng := RandomNumberGenerator.new()
var run_seed := 0
var stage := "attract"
var cash := 0
var ticks := 0
var contract: Dictionary = {}
var supplier: Dictionary = {}
var packaging: Dictionary = {}
var route: Dictionary = {}
var quotes: Array[int] = []
var weather := 0
var quality := 0
var inspected := 0
var quality_report := "尚未验茶"
var packing_step := 0
var cargo_event := ""
var last_line := ""
var ledger: Array[Dictionary] = []
var events: Array[Dictionary] = []
var committed: Dictionary = {}
var result: Dictionary = {}
var session_id := ""
var _reserved := 18
var revision := 0
var rework_count := 0
var exchange_used := false
var loan_principal := 0
var loan_fee := 0
var deferred_cost := 0
var debt_settled := false
var pending_delivery: Dictionary = {}
var inspection_marks: Array[int] = []
var inspection_level := 0
var roast_plan: Dictionary = {}
var roast_step := 0
var work_tool := -1
var approach := "独立接单"
var market_topics: Array[int] = []
var market_topic := -1
var bargain_result: Dictionary = {}
var bargain_beat := 0
var last_treatment: Dictionary = {}

const ROAST_PLANS := [
	{"name":"常火匀焙", "cost":20, "ticks":2, "gain":12},
	{"name":"慢火细理", "cost":24, "ticks":3, "gain":14},
	{"name":"快火抢工", "cost":20, "ticks":1, "gain":8}
]

func _init(config: Dictionary) -> void:
	data = config.duplicate(true)
	reset()

func reset(seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
		run_seed = rng.seed
	else:
		run_seed = seed_value
		rng.seed = seed_value
	stage = "attract"
	revision = 0
	rework_count = 0
	exchange_used = false
	loan_principal = 0
	loan_fee = 0
	deferred_cost = 0
	debt_settled = false
	pending_delivery.clear()
	inspection_marks.clear()
	inspection_level = 0
	roast_plan.clear()
	roast_step = 0
	work_tool = -1
	approach = "独立接单"
	market_topics.clear()
	market_topic = -1
	bargain_result.clear()
	bargain_beat = 0
	last_treatment.clear()
	cash = int(data.initial_cash)
	ticks = 0
	contract = {}
	supplier = {}
	packaging = {}
	route = {}
	quality = 0
	inspected = 0
	packing_step = 0
	quality_report = "尚未验茶"
	cargo_event = ""
	last_line = ""
	ledger.clear()
	events.clear()
	committed.clear()
	result.clear()
	quotes.clear()
	weather = rng.randi_range(0, 2)
	for item in data.suppliers:
		quotes.append(int(round(float(item.cost) * rng.randf_range(0.92, 1.10))))
	session_id = "%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]

func _book(id: String, label: String, amount: int) -> void:
	assert(not committed.has(id), "Duplicate transaction: " + id)
	committed[id] = true
	cash += amount
	ledger.append({"action":id, "label":label, "amount":amount, "balance":cash})

func _event(label: String, detail: String) -> void:
	events.append({"label":label, "detail":detail})
	last_line = detail

func start() -> bool:
	if stage != "attract": return false
	stage = "intro"
	revision += 1
	return true

func choose(index: int, expected_stage: String = "", expected_revision: int = -1) -> bool:
	if expected_stage != "" and expected_stage != stage: return false
	if expected_revision >= 0 and expected_revision != revision: return false
	if index < 0 or index > 2: return false
	var changed := _choose_impl(index)
	if changed: revision += 1
	return changed

func _choose_impl(index: int) -> bool:
	match stage:
		"intro":
			if index > 1: return false
			approach = "请教陈叔" if index == 1 else "独立接单"
			last_line = "先看交期，再想货色。赚到手的钱，才算你的本事。" if index == 1 else "今天这笔茶单，就交给你照应了。"
			stage = "contract"
		"contract":
			contract = data.contracts[index].duplicate(true)
			_book("deposit", "订单预付款", int(data.deposit))
			stage = "market"
			_event("接下订单", "船期已定。先去茶市挑一批合适的货。")
		"market":
			if cash < quotes[index] + _reserved: return false
			supplier = data.suppliers[index].duplicate(true)
			supplier["quote"] = quotes[index]
			stage = "bargain"
			last_line = "这批%s，十箱共%d。你看，怎么成交？" % [supplier.name, supplier.quote]
		"bargain": return _buy(index)
		"bargain_chat":
			if index in market_topics: return false
			market_topics.append(index)
			market_topic = index
			stage = "bargain"
			_event("茶市问话", ["问清了货源与品质起伏。", "问清了取货时间与议价等待。", "问清了茶样与整批货色的区别。"][index])
		"bargain_result":
			if index != 0: return false
			if bargain_beat == 0:
				bargain_beat = 1
			else:
				stage = "inspection"
		"inspection": return _inspect(index)
		"inspection_work":
			if index in inspection_marks: return false
			inspection_marks.append(index)
			last_line = inspection_clue(index)
		"roast_plan": return _begin_roast(index)
		"roasting_work":
			if index != 0 or work_tool != roast_step: return false
			work_tool = -1
			roast_step += 1
			last_line = ["炭火已拨匀，接着翻茶，让热气散开。", "茶已翻匀，再把茶叶收进筛里回凉。", ""][roast_step - 1]
			if roast_step == 3: _finish_roast()
		"remedy": return _remedy(index)
		"shipment_review":
			if index > 1: return false
			stage = "remedy" if index == 0 else "packing"
			last_line = "再看看货色和船期，处理还有代价。" if index == 0 else "已决定带风险装运。未达货色要求，交接时还要另谈价格。"
		"packing": return _pack(index)
		"packing_work":
			if index != 0 or work_tool != packing_step: return false
			work_tool = -1
			packing_step += 1
			if packing_step == 3:
				stage = "packing_seal"
				_event("十箱封妥", "%s，衬料、茶货、封绳已逐步完成。请船家点货装船。" % packaging.name)
		"packing_seal":
			if index != 0: return false
			stage = "dock"
			last_line = "茶箱封好了？江上风色不定，得挑个走法。"
		"dock": return _sail(index)
		"voyage": return _resolve_voyage(index)
		"voyage_report":
			if index != 0: return false
			if not pending_delivery.quality_met:
				stage = "acceptance"
				last_line = "到货货色%d，原单要求%d。我能按%d点收下；若另寻买家，请先取消原单。" % [pending_delivery.quality, contract.quality, pending_delivery.due]
			else: return _settle("standard")
		"acceptance":
			if index > 1: return false
			return _settle("discount" if index == 0 else "resale")
		"arrival":
			if index != 0: return false
			stage = "result"
		"result":
			if index != 0: return false
			stage = "epilogue"
		_: return false
	return true

func _buy(index: int) -> bool:
	var price := int(supplier.quote)
	# Check worst payable cost before drawing: an invalid action must never reroll.
	if cash < price + _reserved: return false
	var outcome := "按报价成交，没有额外耽搁。"
	var success := false
	var delay := 0
	if index > 0:
		var chance := 0.70 if index == 1 else 0.35
		if rng.randf() < chance:
			success = true
			var saving := int(round(price * (0.08 if index == 1 else 0.18)))
			price -= saving
			outcome = "茶商让了%d点，这次议价成了。" % saving
		else:
			delay = 1 if index == 1 else 2
			ticks += delay
			outcome = "茶商不肯让价，照原价成交；议价耽搁了%d格。" % (1 if index == 1 else 2)
	_book("purchase", str(supplier.name), -price)
	ticks += int(supplier.ticks)
	quality = rng.randi_range(int(supplier.quality_min), int(supplier.quality_max))
	if rng.randf() < float(supplier.bad_batch):
		quality = maxi(25, quality - rng.randi_range(15, 30))
	_event("采买成交", outcome)
	bargain_result = {"method":index, "success":success, "quote":int(supplier.quote),
		"paid":price, "saving":int(supplier.quote) - price, "delay":delay,
		"pickup_ticks":int(supplier.ticks)}
	bargain_beat = 0
	stage = "bargain_result"
	return true

func market_conversation(open: bool, expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if open and stage == "bargain":
		stage = "bargain_chat"
	elif not open and stage == "bargain_chat":
		stage = "bargain"
	else: return false
	revision += 1
	return true

func _inspect(index: int) -> bool:
	var cost: int = [0, 8, 18][index]
	if cash < cost: return false
	_book("inspection", ["凭样收货", "抽样开箱", "逐箱复核"][index], -cost)
	ticks += index
	inspection_level = index
	inspection_marks.clear()
	if index > 0:
		quality_report = "正在验茶 · 结果待核"
		stage = "inspection_work"
		last_line = "揭开茶样。看看叶形、辨辨干湿，再看一眼汤色。" if index == 2 else "抽两处茶样看看；抽样只给范围，不能代表每一箱。"
		return true
	_finish_inspection()
	return true

func finish_inspection(expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if stage != "inspection_work" or inspection_marks.size() < inspection_level + 1: return false
	_finish_inspection()
	revision += 1
	return true

func _finish_inspection() -> void:
	var index := inspection_level
	inspected = index
	if index == 0:
		quality_report = "未开箱 · 货色仍未知"
		_event("未验货", "先信茶商这一回，省下工夫。箱里的货色，还得等交付才知道。")
	elif index == 1:
		quality_report = "抽样估计 %d—%d" % [maxi(0, quality - 7), mini(100, quality + 7)]
		_event("抽样结果", "抽样货色约%d—%d，整批仍可能有差异。" % [maxi(0, quality - 7), mini(100, quality + 7)])
	else:
		quality_report = "复核货色 %d / 100" % quality
		_event("复核结果", "这批茶的货色是%d。订单要求%d，如何处置，由你作主。" % [quality, contract.quality])
	stage = "remedy"

func inspection_clue(index: int) -> String:
	var tier := 0 if quality < 65 else (1 if quality < 86 else 2)
	var clues := [
		["叶形碎杂，整齐度欠佳。先别只凭便宜作决定。", "叶形大体齐整，也夹着碎叶；还要照应干湿。", "叶形齐整，碎叶较少；货色仍要结合其他检查。"],
		["捻开后有些发软，干燥状况欠佳。复焙值得考虑。", "捻开略有韧性，干燥状况一般；处理还得算工期。", "捻开干爽，未见明显潮软；上船仍要防潮。"],
		["茶汤较浑，茶样的一致性欠佳。", "茶汤尚清，仔细复核整批才知道能否达标。", "茶汤清亮，茶样状态较好。"]
	]
	return clues[index][tier] + ("（抽样观察）" if inspection_level == 1 else "")

func _remedy(index: int) -> bool:
	if not available(index): return false
	if index == 0:
		stage = "shipment_review" if quality_bounds().x < int(contract.quality) else "packing"
		last_line = "货已备好。包装与船期，还得一起照应。"
		return true
	if index == 1:
		stage = "roast_plan"
		last_line = "火候由你定。慢火多花时间，快火能赶工，提升的货色也不同。"
		return true
	var cost := 34
	var before := quality
	var before_bounds := quality_bounds()
	quality = mini(100, quality + 24)
	last_treatment = {"name":"补价换货", "before":before_bounds, "after":quality_bounds()}
	ticks += 2
	exchange_used = true
	_book("exchange", "补价换货", -cost)
	if inspected > 0:
		quality_report = "处理后货色 %d / 100" % quality if inspected == 2 else "处理后约 %d—%d" % [maxi(0, quality - 7), mini(100, quality + 7)]
	_event("货物处理", "换货完成，花了%d点、多用2格。%s" % [cost,
		"货色%d→%d；可以再决定是否装运。" % [before, quality] if inspected == 2 else "货色提高%d；可以再决定是否装运。" % (quality - before)])
	return true

func _begin_roast(index: int) -> bool:
	var plan: Dictionary = ROAST_PLANS[index]
	if rework_count >= 2 or quality >= 100 or cash < int(plan.cost): return false
	roast_plan = plan.duplicate(true)
	roast_plan["before"] = quality
	rework_count += 1
	_book("rework_%d" % rework_count, "第%d次%s" % [rework_count, plan.name], -int(plan.cost))
	ticks += int(plan.ticks)
	roast_step = 0
	work_tool = -1
	stage = "roasting_work"
	_event("选定火候", "%s，费用%d点、工期%d格已记账。先取火钳拨匀炭火。" % [plan.name, plan.cost, plan.ticks])
	return true

func cancel_roast_plan(expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if stage != "roast_plan": return false
	stage = "remedy"
	last_line = "尚未开焙，未增加支出。再算算货色与船期。"
	revision += 1
	return true

func select_tool(index: int, expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if stage not in ["roasting_work", "packing_work"]: return false
	var needed := roast_step if stage == "roasting_work" else packing_step
	if index != needed or work_tool == needed: return false
	work_tool = index
	revision += 1
	return true

func _finish_roast() -> void:
	var before_bounds := quality_bounds()
	quality = mini(100, quality + int(roast_plan.gain))
	last_treatment = {"name":str(roast_plan.name), "before":before_bounds, "after":quality_bounds()}
	if inspected > 0:
		quality_report = "处理后货色 %d / 100" % quality if inspected == 2 else "处理后约 %d—%d" % [maxi(0, quality - 7), mini(100, quality + 7)]
	stage = "remedy"
	_event("复焙收茶", "%s完成，%s。还可再决定是否装运。" % [roast_plan.name,
		"货色%d→%d" % [roast_plan.before, quality] if inspected == 2 else "货色提高%d" % (quality - int(roast_plan.before))])

func quality_bounds(gain: int = 0) -> Vector2i:
	if inspected == 0: return Vector2i(0, 100)
	var spread := 7 if inspected == 1 else 0
	return Vector2i(clampi(quality - spread + gain, 0, 100), clampi(quality + spread + gain, 0, 100))

func quality_guidance() -> String:
	if inspected == 0: return "未验货，无法判断是否达到%d；仍可处理或带风险装运。" % contract.quality
	var bounds := quality_bounds()
	if bounds.y < int(contract.quality):
		return "当前%s，低于要求%d；%s" % [str(quality) if inspected == 2 else "%d—%d" % [bounds.x, bounds.y], contract.quality,
			"还差%d点。" % (int(contract.quality) - quality) if inspected == 2 else "抽样上限也未达标。"]
	if bounds.x < int(contract.quality): return "抽样区间跨过门槛，仍有不达标的可能。"
	return "当前货色达到门槛；正常运输仍可能降低0—3点。"

func remedy_preview(gain: int) -> String:
	if inspected == 0: return "货色+%d · 尚未验货" % gain
	var bounds := quality_bounds(gain)
	var value := str(bounds.x) if bounds.x == bounds.y else "%d—%d" % [bounds.x, bounds.y]
	return "处理后%s · %s" % [value, "仍未达标" if bounds.y < int(contract.quality) else ("有未达风险" if bounds.x < int(contract.quality) else "达到门槛")]

func debt_due() -> int:
	return 0 if debt_settled else loan_principal + loan_fee + deferred_cost

func can_borrow() -> bool:
	return loan_principal == 0 and stage in ["inspection", "inspection_work", "remedy", "roast_plan", "roasting_work", "shipment_review", "packing", "packing_work", "dock", "voyage"]

func borrow(expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if not can_borrow(): return false
	loan_principal = 60
	loan_fee = 6
	_book("loan", "陈叔周转借款（须归还）", loan_principal)
	_event("一次周转", "陈叔借来60点；结算时还66点。这笔借款不算收入。")
	revision += 1
	return true

func use_deferred(expected_revision: int = -1) -> bool:
	if expected_revision >= 0 and expected_revision != revision: return false
	if stage == "packing":
		packaging = {"name":"赊用旧箱", "cost":12, "ticks":2, "protection":0.05}
		deferred_cost += 12
		_book("deferred_packing", "赊用旧箱（待付12）", 0)
		ticks += 2
		packing_step = 0
		work_tool = -1
		stage = "packing_work"
		_event("赊账装箱", "先赊用旧箱，结算扣12点；耗2格，防潮较弱。")
	elif stage == "dock":
		route = {"name":"候船赊运", "cost":18, "ticks":3, "exposure":1.40}
		deferred_cost += 18
		_book("deferred_freight", "候船赊运（待付18）", 0)
		ticks += 3
		_draw_voyage()
	else: return false
	revision += 1
	return true

func _pack(index: int) -> bool:
	var item: Dictionary = data.packing[index]
	if cash < int(item.cost): return false
	packaging = item.duplicate(true)
	_book("packing", str(item.name), -int(item.cost))
	ticks += int(item.ticks)
	stage = "packing_work"
	packing_step = 0
	work_tool = -1
	return true

func _sail(index: int) -> bool:
	var item: Dictionary = data.routes[index]
	if cash < int(item.cost): return false
	route = item.duplicate(true)
	_book("freight", str(item.name), -int(item.cost))
	ticks += int(item.ticks)
	_draw_voyage()
	return true

func _draw_voyage() -> void:
	var draw := rng.randf()
	var storm_chance: float = [0.18, 0.45, 0.68][weather]
	cargo_event = "squall" if draw < storm_chance else ("leak" if draw < storm_chance + 0.16 else "clear")
	_event("江上消息", {"squall":"风忽然紧了！找岸避一避，还是抢在船期前赶过去？", "leak":"船板渗水，舱底湿了！眼下补漏要花钱，也要花工夫。", "clear":"这一段水路尚平稳。前面船多，要不要雇个帮手赶紧过驳？"}[cargo_event])
	stage = "voyage"

func risk(index: int = 0) -> float:
	if packaging.is_empty() or route.is_empty(): return 0.0
	var base: float = {"squall":0.85, "leak":0.65, "clear":0.15}.get(cargo_event, 0.35)
	var avoidance := 1.0
	if cargo_event == "squall": avoidance = [0.35, 1.0, 0.18][index]
	elif cargo_event == "leak": avoidance = [0.25, 1.0, 0.5][index]
	else: avoidance = [0.8, 1.0, 1.0][index]
	return clampf(base * float(route.exposure) * (1.0 - float(packaging.protection)) * avoidance, 0.01, 0.95)

func _resolve_voyage(index: int) -> bool:
	if index > 1 and cargo_event != "squall": return false
	var cost := 0
	var delay := 0
	if cargo_event == "squall":
		cost = [0, 0, 12][index]
		delay = [2, 0, 1][index]
	elif cargo_event == "leak":
		cost = [12, 0][index]
		delay = [1, 0][index]
	else:
		cost = [8, 0][index]
		delay = [-1, 0][index]
	if cash < cost: return false
	_book("response", "江上应对", -cost)
	ticks = maxi(0, ticks + delay)
	var probability := risk(index)
	var damaged := rng.randf() < probability
	var lost := rng.randi_range(2, 5) if damaged else 0
	var arrival_quality := maxi(0, quality - (rng.randi_range(10, 26) if damaged else rng.randi_range(0, 3)))
	var accepted := int(data.quantity) - lost
	var quality_rate := clampf(1.0 - maxf(0, float(contract.quality) - arrival_quality) * 0.018, 0.25, 1.0)
	var gross := int(round(accepted * int(contract.price) * quality_rate))
	var late := maxi(0, ticks - int(contract.deadline))
	var penalty := late * int(contract.penalty)
	var due := maxi(0, gross - penalty)
	pending_delivery = {"delivered":accepted, "lost":lost, "quality":arrival_quality, "quality_rate":quality_rate,
		"gross":gross, "late":late, "penalty":penalty, "due":due, "risk":probability,
		"damaged":damaged, "ticks":ticks, "quality_met":arrival_quality >= int(contract.quality),
		"resale_gross":int(round(accepted * int(contract.price) * 0.45 * minf(1, float(arrival_quality) / int(contract.quality))))}
	quality_report = "到货货色 %d / 100" % arrival_quality
	_event("驳运结果", "有%d箱受潮损坏，余下%d箱交验。" % [lost, accepted] if damaged else "茶箱顺利到达，这次没有发生运输损货。")
	stage = "voyage_report"
	return true

func _settle(mode: String) -> bool:
	if pending_delivery.is_empty() or committed.has("settlement"): return false
	if mode == "standard":
		if stage != "voyage_report" or not pending_delivery.quality_met: return false
	elif stage != "acceptance" or mode not in ["discount", "resale"]: return false
	var delivery := pending_delivery.duplicate(true)
	var cancellation_fee := 15 if mode == "resale" else 0
	var costs := int(data.initial_cash) + int(data.deposit) + loan_principal - cash + deferred_cost + loan_fee + cancellation_fee
	var due := int(delivery.resale_gross) if mode == "resale" else int(delivery.due)
	var balance_due := due - int(data.deposit)
	_book("settlement", "转售收入抵退预付" if mode == "resale" else ("交货尾款" if balance_due >= 0 else "退回预付款差额"), balance_due)
	if cancellation_fee > 0: _book("cancel_fee", "取消原单费用", -cancellation_fee)
	var repayment := debt_due()
	if repayment > 0: _book("debt_repayment", "借赊清算（不足为缺口）", -repayment)
	debt_settled = true
	result = delivery
	result.merge({"accepted":int(delivery.delivered), "qualified":int(delivery.delivered) if delivery.quality_met else 0,
		"contract_met":mode == "standard" and delivery.quality_met and int(delivery.delivered) == int(data.quantity) and int(delivery.late) == 0,
		"mode":mode, "due":due, "cost":costs, "profit":due - costs, "final_cash":cash,
		"gross":int(delivery.resale_gross) if mode == "resale" else int(delivery.gross),
		"penalty":0 if mode == "resale" else int(delivery.penalty), "cancellation_fee":cancellation_fee,
		"balance_due":balance_due, "debt_settlement":repayment, "funding_gap":maxi(0, -cash), "loan_fee":loan_fee, "deferred_cost":deferred_cost, "seed":str(run_seed)}, true)
	_event("结算", "原单未达标，已由你确认折价成交。" if mode == "discount" else ("原单已取消，转售收入与费用已经入账。" if mode == "resale" else "交验结束，实际收支已入账。"))
	stage = "arrival"
	return true

func available(index: int) -> bool:
	if index < 0 or index > 2: return false
	match stage:
		"market": return cash >= quotes[index] + _reserved
		"bargain": return cash >= int(supplier.quote) + _reserved
		"bargain_chat": return not index in market_topics
		"inspection": return cash >= [0, 8, 18][index]
		"inspection_work": return not index in inspection_marks
		"roast_plan": return cash >= int(ROAST_PLANS[index].cost)
		"roasting_work": return index == 0 and work_tool == roast_step
		"remedy":
			if index == 0: return true
			if index == 1: return rework_count < 2 and quality < 100 and cash >= 20
			return not exchange_used and quality < 100 and cash >= 34
		"packing": return cash >= int(data.packing[index].cost)
		"dock": return cash >= int(data.routes[index].cost)
		"voyage":
			if cargo_event == "squall": return cash >= [0, 0, 12][index]
			if cargo_event == "leak": return index < 2 and cash >= [12, 0][index]
			return index < 2 and cash >= [8, 0][index]
		"intro", "shipment_review", "acceptance": return index < 2
		"packing_work": return index == 0 and work_tool == packing_step
		"bargain_result", "packing_seal", "voyage_report", "arrival", "result": return index == 0
		"attract", "epilogue": return false
	return true

func unavailable_reason(index: int) -> String:
	if stage == "bargain_chat" and index in market_topics: return "已经问过，可换个话题"
	if stage == "remedy" and index > 0:
		if quality >= 100: return "已到上限"
		if index == 1 and rework_count >= 2: return "已复焙两次"
		if index == 2 and exchange_used: return "已换过货"
	return "资金不足"

func location() -> String:
	if stage in ["market", "bargain", "bargain_chat", "bargain_result"]: return "market"
	if stage in ["inspection", "inspection_work", "remedy", "shipment_review"]: return "inspection"
	if stage in ["roast_plan", "roasting_work"]: return "roasting"
	if stage in ["packing", "packing_work", "packing_seal"]: return "packing"
	if stage in ["voyage", "voyage_report"]: return "vessel"
	if stage in ["dock", "acceptance", "arrival"]: return "dock"
	return "counter"

func chapter() -> int:
	if stage in ["attract", "intro", "contract"]: return 0
	if stage in ["market", "bargain", "bargain_chat", "bargain_result", "inspection", "inspection_work", "remedy", "shipment_review", "roast_plan", "roasting_work"]: return 1
	if stage in ["packing", "packing_work", "packing_seal"]: return 2
	if stage in ["dock", "voyage", "voyage_report"]: return 3
	return 4

func ending() -> Array:
	if result.is_empty(): return ["茶船将发", "这一趟还在路上。", "先把手里的事做完。"]
	if result.funding_gap > 0: return ["一笔未清的账", "茶船走了，账房还留着%d点缺口。陈叔陪你把每项支出重新写清。" % result.funding_gap, "下次先留周转钱；赊下的费用，终究要还。"]
	if result.mode == "resale": return ["换一个买主", "原单取消后，你为%d箱茶另寻出路。梁老板帮着牵线，阿顺等你重新点货。" % result.delivered, "止损也要算清改单费和预付款，才知道收回了多少。"]
	if result.contract_met and result.profit >= 0: return ["陈叔把账本交给你", "十箱茶如约交清。这一单收支相抵，陈叔让你把打平的账也仔细记好。" if result.profit == 0 else "十箱茶如约交清。交接人合上货单，陈叔让你亲手记下这笔%d点的盈余。" % result.profit, "从选茶到封箱，你终于独立照应完一笔生意。"]
	if result.lost > 0: return ["湿了的茶箱", "阿顺把%d箱损货摆在岸边。你点清余货，也把这次风雨的代价记进账里。" % result.lost, "路上的风险压不成零；包装、路线和应对，都有分量。"]
	if result.late > 0: return ["赶上货，误了期", "茶到了，原定交期却已过去%d格。交接人按约扣款，陈叔提醒你回看一路的等待。" % result.late, "货色值得照应，船期也要从接单时一起算。"]
	if not result.quality_met: return ["货色之外，还有商量", "交接人指出货色差距。你确认折价，让茶货仍有去处，也在账上留下未达标的记录。", "卖出去与如约交付，是两件需要分别照应的事。"]
	return ["交清了货，蚀了本", "茶货交清了，成本却吃掉了货款。陈叔把账本推来，让你找出最贵的那一步。", "每次补救都有效果，也都有价钱。"]

func weather_name() -> String:
	return ["天色尚晴", "云低欲雨", "风雨将至"][weather]
