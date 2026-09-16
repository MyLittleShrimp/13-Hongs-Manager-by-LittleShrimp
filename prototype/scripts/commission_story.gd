extends RefCounted
## Fictional commissions: observations read committed facts, never determine them.
const STORIES := {
	"regular": {
		"title":"老客又来订茶", "tag":"守约 · 照应本钱", "image":"inspection",
		"pitch":"上回茶货交得齐整，\n老客又托怀特带来一封订单。",
		"letter":"上回的茶按约送到，箱数也齐。这回仍请备十箱，不必一味抢快，盼望交来的货与约定一样稳妥。",
		"promise":"把货交齐、按约送到，也给行号留下本钱。"},
	"urgent": {
		"title":"黄埔有船等着茶", "tag":"赶船 · 留足周转", "image":"vessel",
		"pitch":"装货清单还缺十箱茶，\n怀特愿加价，船期却不能改。",
		"letter":"商船的开航日已经排定，装货清单上还缺十箱茶。愿加价催办，请把验货、装箱与驳运的日子一起算清，切莫只顾眼前一步。",
		"promise":"多付的货价，是为按时收到茶；赶路也得护住货。"},
	"premium": {
		"title":"这一回，要照茶样交", "tag":"验清 · 护住货色", "image":"roasting",
		"pitch":"客人上次退过一批货，\n这回带着茶样，请怀特把关。",
		"letter":"上回收到的货与茶样有差，客人退回了茶。这回宁肯多付些，也要把成色看清。请逐项照应，交货时仍要再验。",
		"promise":"装船前达标只是一步，路上受潮也会损伤货色。"}
}

static func profile(contract: Dictionary) -> Dictionary:
	return STORIES.get(str(contract.get("story_key", "regular")), STORIES.regular)

static func market(t) -> String:
	match str(t.contract.get("story_key", "regular")):
		"urgent": return "黄埔那条船在等茶？现货拿得快，本钱高些；远仓省钱，却得多等。还要给验茶和驳运留出日子。"
		"premium": return "带茶样来的那位客人，我记得。精拣货也得开箱看，报价高不能替十箱货的成色作保。"
	return "老客又来订茶，靠的是上回守约。三处货源摆在这里，你把本钱、取货日子和货色一并掂量。"

static func packing(t) -> String:
	var remaining: int = int(t.contract.deadline) - int(t.ticks)
	match str(t.contract.get("story_key", "regular")):
		"urgent": return "这单%s。封箱不能马虎；省下一天，也得让茶货经得住江上这趟路。" % ("已逾期%d天" % -remaining if remaining < 0 else "还剩%d天交货" % remaining)
		"premium": return "客人会照茶样再验。前面已经复焙%d次，箱里更得护住干爽，别让路上的潮气吃掉工夫。" % int(t.rework_count)
	return "老客盼的是十箱齐整。包装花钱要算，防潮也别省过头；本金还要留着走完这趟路。"

static func dock(t) -> String:
	var remaining: int = int(t.contract.deadline) - int(t.ticks)
	match str(t.contract.get("story_key", "regular")):
		"urgent":
			return "十箱点齐。已经逾期%d天，先把余下路程和扣款算清，再挑走法。" % -remaining if remaining < 0 else "十箱点齐，离交货还剩%d天。快船、合运、沿岸走，花费和用时都写在下方。" % remaining
		"premium": return "客人要照茶样验收。箱子封好了，船上仍可能受潮；快慢之外，也看看搬运和风浪。"
	return "老客这单，十箱都点到了。走得快、走得稳，各有价钱；别只省船钱，也别把本钱全花光。"

static func closing(t) -> Dictionary:
	var r: Dictionary = t.result
	var key := str(t.contract.get("story_key", "regular"))
	var title := str(profile(t.contract).title)
	var buyer := ""
	if r.mode == "resale":
		buyer = "原单已取消，这十箱的委托没有如约完成。余货另寻买主，转售价与改单费都已记在账上。"
	elif key == "urgent":
		if r.late > 0: buyer = "茶送到了，约定的交期却已过去%d天。怀特按约扣下%d币；这张急单留下了一笔迟交记录。" % [r.late, r.penalty]
		elif not r.quality_met: buyer = "交期赶上了，货色却没到约定的门槛。怀特与你商量折价，急单仍留下未达标的记录。"
		elif r.lost > 0: buyer = "交期赶上了，怀特却只点到%d箱。船期之外，少交的%d箱也是这单要面对的结果。" % [r.delivered, r.lost]
		else: buyer = "怀特在清单上核过十箱，货色和交期都合约。等茶的这份急单，总算按约交清。"
	elif key == "premium":
		if not r.quality_met: buyer = "怀特照着茶样验货：到货货色%d，仍低于要求%d。你确认折价成交，这次没有达到原单标准。" % [r.quality, t.contract.quality]
		elif r.lost > 0: buyer = "到货货色%d达到了要求，怀特却只收到%d箱。成色过关，也不能抵掉缺少的箱数。" % [r.quality, r.delivered]
		elif r.late > 0: buyer = "这一批货色%d，过了客人的门槛；但交期迟了%d天。怀特记下好货，也照约记下扣款。" % [r.quality, r.late]
		else: buyer = "怀特验过十箱茶，货色%d达到约定，也如期交齐。那位带茶样来的客人，这回有了合约的交代。" % r.quality
	else:
		if r.contract_met: buyer = "十箱齐、货色合约、交期也守住了。怀特在老客的订单上签下交清，这份信任有了着落。"
		else: buyer = "老客盼着按约收到十箱。怀特记下了这次%s，余下的茶货仍按实际交接结果结账。" % ("少交%d箱" % r.lost if r.lost > 0 else ("迟交%d天" % r.late if r.late > 0 else "货色未达标"))
	var master: String
	if r.funding_gap > 0: master = "陈叔：清算还差%d币，借赊没有免除。把这笔缺口记清，下回先留周转。" % r.funding_gap
	elif r.profit < 0: master = "陈叔：这单亏了%d币。交货的结果与行号的盈亏，要分开算；本钱花在哪儿，账本里都有。" % -int(r.profit)
	elif r.profit == 0: master = "陈叔：收支持平。交货的结果记清，成本也别漏掉；这一趟的工夫，值得回看。"
	else: master = "陈叔：这单赚了%d币。%s" % [r.profit, "也守住了委托的约定。" if r.contract_met else "赚到钱，也要记得原单没有完全履约。"]
	return {"title":title, "buyer":buyer, "master":master}
