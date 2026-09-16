extends RefCounted
## Dialogue reads committed trade facts; it never changes prices or draws randomness.

static func welcome(t) -> String:
	if int(t.contract.deadline) <= 7:
		return "赶黄埔的船？先看看取货要几天。远仓便宜，搬到这里可要工夫。"
	if int(t.contract.quality) >= 86:
		return "上等茶单啊。精拣货本钱高些，也得开箱验；光看这碟茶样，不能替十箱货作保。"
	return "新管事，来看看茶。三处货源，价钱和取货工夫都写着，咱们把账谈明白。"

static func before_offer(t) -> String:
	match t.market_topic:
		0:
			return {"远仓散茶":"这是远仓收来的散茶，批次杂，货色起伏大。便宜归便宜，验货得留心。",
				"街坊茶庄":"街坊货源较稳，取货也适中。可茶样只是一小撮，整批仍得你自己验。",
				"精拣现货":"这批已经精拣，取货快，本钱也高。拣过不等于箱箱无差，还是要验。"}.get(t.supplier.name, "先看看货源，再定价钱。")
		1:
			return "取这批货要%d天。你这单限%d天；若还价没谈成，还会多等1或2天。船期可不等人。" % [t.supplier.ticks, t.contract.deadline]
		2:
			return "桌上是茶样，不是验货结论。成交后可以抽样，也能逐箱复核；让了价，也得照样验清。"
	return "十箱%s，今日共%d币。你有船期，我有本钱。这口价，你打算怎么谈？" % [t.supplier.name, t.supplier.quote]

static func reply(t) -> Array:
	var r: Dictionary = t.bargain_result
	if t.bargain_beat == 1:
		if r.saving > 0:
			return ["player", "货单我收好了，省下%d币。梁老板，再带我去验茶台，价钱和货色都得记清。" % r.saving]
		if r.delay > 0:
			return ["player", "这回没让下价，还多耗了%d天。把货单记清，接下来验货和船期都得算紧些。" % r.delay]
		return ["player", "价钱记清，十箱点齐。省下还价的工夫，接下来把货色验明白。"]
	if r.method == 0:
		return ["merchant", "爽快，按%d币成交。我把货单写好，咱们不在还价上耽搁。" % r.paid]
	if r.success:
		return ["merchant", ("十箱一起收，就匀你%d币。按%d币记账，验茶时再把箱里的货看仔细。" if r.method == 1 else "这口价压得紧……好，这回让%d币，按%d币记。茶样在这儿，货还是要验。") % [r.saving, r.paid]]
	if r.method == 1:
		return ["merchant", "这口价实在让不动，还是%d币。咱们来回谈，已经多耗了%d天。" % [r.paid, r.delay]]
	return ["merchant", "本钱摆着，再低做不了。来回多耗了%d天，最后还是按%d币成交。货单给你。" % [r.delay, r.paid]]

static func inspection_open(t) -> String:
	var r: Dictionary = t.bargain_result
	if r.is_empty(): return "茶样已摆上桌，验到什么程度，由你决定。"
	if r.saving > 0: return "刚才让的%d币已写进货单。现在开箱看看，验到什么程度，由你决定。" % r.saving
	if r.delay > 0: return "还价已多耗%d天，验茶也要工夫。赶船要紧，箱里的货色也得心里有数。" % r.delay
	return "价钱已结清，茶样也摆好了。凭样省工，开箱更有把握，你来定。"

static func inspection_response(t) -> String:
	if t.inspected == 0: return "价钱记清了，货色还未知。我得给后头的风险留条路。"
	var r: Dictionary = t.bargain_result
	var bounds: Vector2i = t.quality_bounds()
	if bounds.y < int(t.contract.quality):
		return "让价省下%d币，可这批货还得处理。先看看差距。" % r.saving if r.get("saving", 0) > 0 else "价钱谈妥了，货色还有差距。先算补救要花多少。"
	if bounds.x < int(t.contract.quality):
		return "抽样范围跨着订单的门槛，还不能确定达标。我得给可能的货色差距留些余地。"
	return "货色有了依据，再看看包装和船期怎么安排。"

static func ending_echo(t) -> String:
	var r: Dictionary = t.bargain_result
	if r.is_empty(): return "从接茶单到交清账，原来每一步都算数。"
	if r.delay > 0:
		return "陈叔，茶市还价多耗了%d天。以后谈价前，我会先给验茶和运货留足工夫。" % r.delay
	if r.saving > 0:
		return "陈叔，茶市虽省了%d币，最后还是亏了本。我得把后面的支出与风险一起算。" % r.saving if t.result.profit < 0 else "陈叔，茶市省下%d币只是开头；这笔生意的收支，还得一路算到交货。" % r.saving
	return "陈叔，这次照价成交，没在还价上等。下次我会把价钱、货色和船期一起掂量。"
