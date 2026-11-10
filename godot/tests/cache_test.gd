extends SceneTree
## The keep-EV cache must never be stale. After every engine operation that
## can touch dealt or stock, the cached table must equal a fresh computation.
##   godot --headless --path godot --script res://tests/cache_test.gd
const CASES := 300

var checks := 0
var stale := 0

func _verify(rd, where: String) -> void:
	if rd.dealt == null or rd.phase != "keep":
		return
	checks += 1
	var fresh := Cribbage.keep_options_ev(rd.dealt, rd.stock, rd.keep_count(), rd.mods)
	if load("res://tests/parity_test.gd").diff(fresh, rd.keep_table()) != "":
		stale += 1
		if stale <= 5:
			print("STALE after ", where)

func _initialize() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	JS.unseeded = JsRng.new(4242)
	var g := JsRng.new(777)
	var builds := [[], ["foresight", "recut"], ["foresight", "recut", "steadyhand"], ["doublecut", "recut"], ["secondchance"]]
	for k in CASES:
		var run := CribRun.new(["pip", "facet", "nib", "thump"][k % 4], null, Meta.TRIALS[3] if k % 7 == 0 else null, 1000 + k)
		for id in builds[k % builds.size()]:
			run.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(run)
		var guard := 0
		while not rd.over and guard < 40:
			guard += 1
			if rd.new_deal() == null:
				break
			_verify(rd, "new_deal")
			rd.best_keep_ev()                 # warm the cache, then mutate
			var steps := int(g.next() * 4)
			for s in steps:
				var op := int(g.next() * 3)
				if op == 0 and rd.mulligan() != null:
					_verify(rd, "mulligan")
				elif op == 1 and rd.starter != null and rd.recut() != null:
					_verify(rd, "recut")
				elif op == 2 and rd.starter == null:
					rd.cut_starter()
					_verify(rd, "cut_starter")
				rd.keep_table()
			rd.commit(rd.best_keep_ev().idx)
		if not rd.over:
			rd.settle()
	print("cache checks %d, stale %d" % [checks, stale])
	print("CACHE OK" if stale == 0 and checks > 0 else "CACHE FAILED")
	quit(0 if stale == 0 and checks > 0 else 1)
