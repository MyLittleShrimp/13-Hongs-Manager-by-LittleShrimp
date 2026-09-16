extends RefCounted
## Only expose the precision the player has obtained through inspection.

static func range_text(bounds: Vector2i) -> String:
	return str(bounds.x) if bounds.x == bounds.y else "%d—%d" % [bounds.x, bounds.y]

static func headline(t) -> String:
	if t.inspected == 0: return "当前货色未知"
	return ("当前货色估计 " if t.inspected == 1 else "当前货色 ") + range_text(t.quality_bounds())

static func comparison(t) -> String:
	if t.last_treatment.is_empty(): return ""
	if t.inspected == 0: return str(t.last_treatment.name) + "已完成 · 尚未验明货色"
	return "%s：%s → %s" % [t.last_treatment.name,
		range_text(t.last_treatment.before), range_text(t.last_treatment.after)]

static func roast_response(t) -> String:
	if t.inspected == 0: return "这一筛已经回凉收好。货色尚未验明，后头的风险还得留心。"
	var bounds: Vector2i = t.quality_bounds()
	if bounds.y < int(t.contract.quality):
		return "收茶了，货色还没到订单门槛。再算算补救与带风险装运，各要付什么代价。"
	if bounds.x < int(t.contract.quality):
		return "这一焙收好了，抽样范围仍跨着门槛。结果记在中间，装运前再掂量一下。"
	return "茶已回凉，当前货色达到门槛。看清这一焙的变化，再把包装和船期照应好。"
