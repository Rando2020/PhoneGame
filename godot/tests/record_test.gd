extends SceneTree
## A lost Daily locks the Daily for its date (and the roads screen says so); a
## lost Long Count saves its best round and a worse one doesn't lower it. Runs
## real rounds (keeping the worst four cards) and ends them through RunFlow's
## own round end, as web/record_check.js does through the web's.
##   godot --headless --path godot --script res://tests/record_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


## Play rounds badly until one is lost; every round ends through RunFlow.
func lose(f: RunFlow) -> Dictionary:
	for r in 25:
		var rd := CribRound.new(f.run)
		while not rd.over:
			if rd.new_deal() == null:
				break
			var idx: Array = range(rd.dealt.size())
			idx.sort_custom(func(a, b): return rd.dealt[a].rank < rd.dealt[b].rank)
			rd.commit(idx.slice(0, rd.keep_count()))
			if not (rd.deals_left > 0 and rd.score < rd.target):
				break
		f.rd = rd
		f._paid = false
		f._round_end_effects()
		if not rd.won:
			return {"won": false, "score": rd.score, "idx": f.run.round_index()}
		if f.run.endless:
			f.run.endless_round += 1
		else:
			f.run.advance()
	return {"won": true}


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1280)
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	for key in ["2026-10-18", "2026-11-02", "2027-01-01"]:
		Achv.save_store({"__v": 3})
		var seed := Meta.daily_seed(key)
		f.run = CribRun.new(["pip", "thump", "clover", "facet"][seed % 4], Meta.STREETS[0], null, seed)
		f.run.daily = key
		var out := lose(f)
		ok(not out.won, "daily %s: meant to lose" % key)
		var done = Achv.daily_done(key)
		ok(done != null and int(done.reached) == int(out.idx) - 1 and int(done.score) == int(out.score), "daily %s: recorded %s" % [key, done])
		ok(Achv.daily_done("1999-01-01") == null, "another date stays open")
		f.show_front_door("road")
		f.front.today = key
		f.front.render()
		await process_frame
		ok(f.front.buttons["daily"].disabled, "daily %s: still open after a lost attempt" % key)
		ok(f.front.buttons["daily"].get_child(1).text == "Done: reached %d. Come back tomorrow." % (int(out.idx) - 1), "daily %s: note '%s'" % [key, f.front.buttons["daily"].get_child(1).text])
	for meld in ["pip", "facet"]:
		Achv.save_store({"__v": 3})
		f.run = CribRun.new(meld, Meta.STREETS[0])
		f.run.enter_endless()
		f.run.endless_round = 2
		var out2 := lose(f)
		ok(not out2.won and Achv.best_endless() == int(out2.idx) - 1, "endless %s: best %d, expected %d" % [meld, Achv.best_endless(), int(out2.idx) - 1])
		Achv.set_endless(5)
		ok(Achv.best_endless() == int(out2.idx) - 1, "a worse Long Count lowered the best")
	print("record checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 19
	print("RECORD OK" if good else "RECORD FAILED")
	quit(0 if good else 1)
