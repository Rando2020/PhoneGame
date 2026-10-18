extends SceneTree
## Per-call cost of the engine operations the UI makes every deal.
## Averages over many deals so one lucky/unlucky hand doesn't skew it.
const DEALS := 40

func _ms(t: int) -> float:
	return (Time.get_ticks_usec() - t) / 1000.0

func _initialize() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	var acc := {"best_keep_ev": 0.0, "keep_rank": 0.0, "preview": 0.0, "best_order": 0.0, "commit": 0.0, "cut_quality": 0.0}
	var n_count := 0
	var t_count := 0.0
	for d in DEALS:
		var run := CribRun.new(["thump", "pip", "clover", "facet"][d % 4], null, null, 99 + d)
		for id in ["keystone2", "ballast", "tallyman", "groundwork", "fifteener"]:
			run.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(run)
		rd.new_deal()
		var t := Time.get_ticks_usec()
		var best := rd.best_keep_ev()
		acc.best_keep_ev += _ms(t)
		t = Time.get_ticks_usec(); rd.keep_rank(best.idx); acc.keep_rank += _ms(t)
		t = Time.get_ticks_usec(); rd.preview(best.idx); acc.preview += _ms(t)
		var kept: Array = best.idx.map(func(i): return rd.dealt[i])
		t = Time.get_ticks_usec(); run.best_order(rd, kept); acc.best_order += _ms(t)
		t = Time.get_ticks_usec(); rd.commit(best.idx); acc.commit += _ms(t)
		t = Time.get_ticks_usec(); rd.cut_quality(kept, rd.starter); acc.cut_quality += _ms(t)
		t = Time.get_ticks_usec()
		for i in 200:
			Cribbage.count_hand(kept, rd.starter, false, rd.mods)
		t_count += Time.get_ticks_usec() - t
		n_count += 200
	var line := ""
	for k in acc:
		line += "%s %.2f ms | " % [k, acc[k] / DEALS]
	print(line + "count_hand %.1f us" % (t_count / n_count))
	var keep_path: float = (acc.best_keep_ev + acc.keep_rank) / DEALS
	print("keep decision path (best_keep_ev + keep_rank): %.2f ms per deal" % keep_path)
	quit()
