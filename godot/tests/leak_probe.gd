extends SceneTree
## Plays 3 rounds and reports live Object count, to catch reference cycles.
func _initialize() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for k in 3:
		var run := CribRun.new("pip", null, null, 1234 + k)
		for r in 3:
			var rd := CribRound.new(run)
			while not rd.over:
				if rd.new_deal() == null:
					break
				rd.commit(rd.best_keep_ev().idx)
			if not rd.over:
				rd.settle()
	var after := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("objects alive after 3 runs x 3 rounds: +%d" % (after - before))
	quit()
