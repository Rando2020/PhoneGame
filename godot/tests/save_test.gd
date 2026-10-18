extends SceneTree
## Save and resume. Replays the 78 fixture runs (every Meldling, Streets 1/3/5/8,
## all Trials, endless, forced mythic builds) through parity_runs.gd, but SAVES
## AND RELOADS THE WHOLE GAME at four points in every deal and round: round
## start, before each deal, after each count, after the shop. The reloaded game
## must play on to exactly the JS's results. Also: a save written twice in a
## row is byte-identical, and card / charm identity survives a reload.
##   godot --headless --path godot --script res://tests/save_test.gd
var checks := 0
var fails := 0
var passes := {}
var fx


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 10:
			print("FAIL ", m)


# parity_runs.gd talks to its test through these
func check(group: String, name: String, want, got) -> bool:
	var d := diff(want, got)
	ok(d == "", "%s %s:%s" % [group, name, d])
	return d == ""
func diff(a, b, where := "") -> String:
	return load("res://tests/parity_test.gd").diff(a, b, where)
func norm(v):
	return load("res://tests/parity_test.gd").norm(v)
func card_out(c):
	return _card_out(c)
func _card_out(c) -> Dictionary:
	var o := {"rank": c.rank, "suit": c.suit}
	for k in ["enh", "rank2", "suit2"]:
		if c.has(k) and c[k] != null:
			o[k] = c[k]
	return o


func _initialize() -> void:
	_go.call_deferred()


var stable := 0
var _shown := false
var identity := 0


func roundtrip(run, rd) -> Array:
	var a := SaveGame.dump(run, rd)
	var b := SaveGame.dump(run, rd)
	if a != b:
		ok(false, "dump not stable")
	else:
		stable += 1
	var back := SaveGame.load_(a)
	# identity: the same card object everywhere it appears
	if rd != null and back[1] != null and not back[1].stock.is_empty() and not back[0].cards.is_empty():
		var r2: CribRound = back[1]
		var found := false
		for c in r2.stock:
			for d in back[0].cards:
				if is_same(c, d):
					found = true
		if run.cards.size() > 0 and rd.stock.size() > 0:
			var orig := false
			for c in rd.stock:
				for d in run.cards:
					if is_same(c, d):
						orig = true
			ok(found == orig, "card identity lost across reload")
			identity += 1
	# a reload re-saves to the same text: nothing lost, nothing invented
	var again := SaveGame.dump(back[0], back[1])
	if again != a and not _shown:
		_shown = true
		var A: Dictionary = str_to_var(a)
		var B: Dictionary = str_to_var(again)
		for part in ["run", "round"]:
			if A[part] is Dictionary:
				for k in A[part]:
					if var_to_str(A[part][k]) != var_to_str(B[part].get(k)):
						print("DIFF ", part, ".", k, ": ", var_to_str(A[part][k]).left(300), "  vs  ", var_to_str(B[part].get(k)).left(300))
		if var_to_str(A.cards) != var_to_str(B.cards):
			print("DIFF cards ", A.cards.size(), " vs ", B.cards.size())
	ok(again == a, "reload re-saves differently")
	return [back[0], back[1]]


func _go() -> void:
	var f := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	fx = norm(JSON.parse_string(f.get_as_text()))
	var pr = load("res://tests/parity_runs.gd").new()
	pr.hook = roundtrip
	var t0 := Time.get_ticks_msec()
	var lim: int = fx.runs.size()
	if OS.get_environment("SAVE_RUNS") != "":
		lim = mini(lim, int(OS.get_environment("SAVE_RUNS")))
	pr.T = self
	var matched := 0
	for i in lim:
		var r = fx.runs[i]
		var got: Dictionary = pr.play_run(r.cfg)
		if check("runs", "%d (%s st%d)" % [i, r.cfg.meld, r.cfg.street], r.trace, got):
			matched += 1
	print("save: %d of %d runs match the JS with %d save/reloads (%d stable, %d identity checks), %d ms" % [matched, lim, pr.hooked, stable, identity, Time.get_ticks_msec() - t0])
	var good: bool = fails == 0 and matched == lim and pr.hooked >= 1000
	print("save checks: %d, failures: %d" % [checks, fails])
	print("SAVE OK" if good else "SAVE FAILED")
	quit(0 if good else 1)
