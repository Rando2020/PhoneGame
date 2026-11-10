extends SceneTree
## Free to try (pass 13): one place says "full"; free runs stop after act 1.
## Checks, with a stand-in MeldStore:
## - the cap: beating act 1 round 5 in free mode leads to the end card, never to
##   act 1's shop or act 2; a run at act 2 (a save, a refund) can't start a
##   round; resuming at the card or at the won round end stays capped
## - the end card's pitch counts match the game data
## - purchase: unlocks for good and continues the same run into the shop
## - cancelled / failed purchase: stays on the card, says so, still free
## - restore: with the unlock, continues; without, says nothing to restore
## - Not now: the run ends, recorded, Pegs paid once, title
## - unlocked: act 1 round 5 won goes to the shop as before (no card)
##   godot --headless --path godot --script res://tests/entitlement_test.gd
var checks := 0
var fails := 0


class FakeStore extends Object:
	signal purchased(id: String)
	signal restored(ids: Array)
	signal failed(id: String, reason: String)
	var mode := "ok"                ## ok / cancelled / failed
	var owned := false
	var calls := []
	func products() -> Array:
		return [{"id": Entitlement.FULL_ID, "price": "$2.99"}]
	func purchase(id: String) -> void:
		calls.append("purchase")
		match mode:
			"ok":
				owned = true
				purchased.emit(id)
			"cancelled":
				failed.emit(id, "cancelled")
			_:
				failed.emit(id, "network")
	func restore() -> void:
		calls.append("restore")
		restored.emit([Entitlement.FULL_ID] if owned else [])


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A run whose act 1 round 5 (the first Spoiler) has just been won.
func _won_first_spoiler(f: RunFlow) -> CribRun:
	var run := CribRun.new("thump", null, null, 77)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		run.charms.append(CribData.charm_by_id(id))
	run.round = CribData.ROUNDS
	f.run = run
	var rd := CribRound.new(run)
	while rd.new_deal() != null:
		rd.commit(rd.best_keep_ev().idx)
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	f.rd = rd
	f._paid = false
	f._round_end_effects()
	f._render_round_end()
	f.settle()
	return run


func _flow() -> RunFlow:
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	return f


func _go() -> void:
	# a broken build can stall the test (a button that isn't there): fail, don't hang
	create_timer(120.0).timeout.connect(func():
		print("FAIL watchdog: the test stalled")
		print("entitlement_test: %d checks, %d fails" % [checks, fails + 1])
		quit(1))
	Achv.persist = false
	Achv.save_store({"__v": 3, "drag_hint": 1})
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = true
	Entitlement.force = false
	var fs := FakeStore.new()
	Engine.register_singleton("MeldStore", fs)
	var f := _flow()
	await _frames(3)
	# ---- the cap at the first Spoiler
	var run := _won_first_spoiler(f)
	ok(f.rd.won, "setup: the first Spoiler round wasn't won")
	ok(not f.buttons.has("shop") and f.buttons.has("free_next"), "free mode: the round end offers the shop, not the end card")
	if f.buttons.has("free_next"):
		f.buttons["free_next"].emit_signal("pressed")
	f.settle()
	ok(f.screen == "free_end", "WHAT'S NEXT didn't open the end card (%s)" % f.screen)
	ok(f.buttons.has("unlock") and f.buttons.has("restore") and f.buttons.has("not_now"), "end card buttons")
	ok(String(f.buttons["unlock"].text).contains("$2.99"), "the unlock button lacks the store's price: %s" % f.buttons["unlock"].text)
	# the pitch: counts from the data
	var want := "%d more acts and %d more Spoilers this run, then %d more streets, %d trials" % [
		CribData.ACTS - 1, run.boss_plan.size() - 1, Meta.STREETS.size() - 1, Meta.TRIALS.size()]
	var texts := f._page.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	ok(texts.any(func(t): return String(t).contains(want)), "pitch counts: want '%s'" % want)
	ok(not texts.any(func(t): return String(t).contains("—")), "em dash on the end card")
	# act 2 can't start in free mode, by any route
	run.act = 2
	run.round = 1
	f.show_intro()
	ok(f.screen == "free_end", "free mode: an act 2 intro started (%s)" % f.screen)
	f.save_now()
	var saved := f.last_save
	var g := _flow()
	await _frames(2)
	g.last_save = saved
	g.resume()
	g.settle()
	ok(g.screen == "free_end", "free mode: resuming an act 2 save started play (%s)" % g.screen)
	g.queue_free()
	run.act = 1
	run.round = CribData.ROUNDS
	# ---- cancelled, then failed: still free, the card says so
	f.show_free_end()
	fs.mode = "cancelled"
	f.buttons["unlock"].emit_signal("pressed")
	await process_frame
	ok(f.screen == "free_end" and not JS.truthy(Achv.load_store().get("full")), "cancelled purchase unlocked or left the card")
	ok(f.free_status.text.contains("cancelled"), "cancel not said: %s" % f.free_status.text)
	fs.mode = "failed"
	f.buttons["unlock"].emit_signal("pressed")
	await process_frame
	ok(f.screen == "free_end" and not JS.truthy(Achv.load_store().get("full")), "failed purchase unlocked or left the card")
	ok(f.free_status.text.contains("didn't go through"), "failure not said: %s" % f.free_status.text)
	# restore with nothing bought
	f.buttons["restore"].emit_signal("pressed")
	await process_frame
	ok(f.screen == "free_end" and f.free_status.text.contains("Nothing to restore"), "empty restore: %s" % f.free_status.text)
	# ---- purchase: unlocked for good, the same run goes on into the shop
	var before := SaveGame.dump(run, null, {})
	fs.mode = "ok"
	f.buttons["unlock"].emit_signal("pressed")
	await process_frame
	f.settle()
	ok(JS.truthy(Achv.load_store().get("full")), "purchase didn't save the unlock")
	ok(f.screen == "shop" and f.run == run, "purchase didn't continue the same run into the shop (%s)" % f.screen)
	ok(SaveGame.dump(run, null, {}).length() >= before.length() - 1 and run.act == 1 and run.round == CribData.ROUNDS, "the run changed on unlock")
	Entitlement.force = null
	ok(Entitlement.full(), "the saved unlock isn't full")
	# unlocked: the next round is act 2, and the round end goes to the shop
	f.shop.next_button.emit_signal("pressed")
	f.settle()
	ok(f.screen == "intro" and run.act == 2 and run.round == 1, "unlocked: didn't reach act 2 (%s, %d-%d)" % [f.screen, run.act, run.round])
	var f2 := _flow()
	await _frames(2)
	_won_first_spoiler(f2)
	ok(f2.buttons.has("shop") and not f2.buttons.has("free_next"), "unlocked: the round end still shows the end card")
	f2.queue_free()
	# ---- restore on a fresh device: continues
	Achv.save_store({"__v": 3, "drag_hint": 1})
	Entitlement.force = null
	fs.owned = true
	ok(not Entitlement.full(), "a fresh store with a plugin present shouldn't be full")
	var f3 := _flow()
	await _frames(2)
	_won_first_spoiler(f3)
	f3.buttons["free_next"].emit_signal("pressed")
	f3.settle()
	f3.buttons["restore"].emit_signal("pressed")
	await process_frame
	f3.settle()
	ok(Entitlement.full() and f3.screen == "shop", "restore didn't unlock and continue (%s)" % f3.screen)
	f3.queue_free()
	# ---- Not now: the run ends, recorded, Pegs paid once
	Achv.save_store({"__v": 3, "drag_hint": 1})
	fs.owned = false
	var f4 := _flow()
	await _frames(2)
	_won_first_spoiler(f4)
	f4.buttons["free_next"].emit_signal("pressed")
	f4.settle()
	var pegs0 := Achv.pegs()
	var runs0: int = Achv.load_store().get("history", []).size()
	f4.buttons["not_now"].emit_signal("pressed")
	f4.settle()
	ok(Achv.pegs() == pegs0 + Meta.pegs_for_loss(CribData.ROUNDS), "Not now paid %d Pegs, want %d" % [Achv.pegs() - pegs0, Meta.pegs_for_loss(CribData.ROUNDS)])
	ok(f4.screen != "free_end" and f4.run == null and not f4.has_save(), "Not now didn't end the run (%s)" % f4.screen)
	ok(Achv.load_store().get("history", []).size() == runs0 + 1, "Not now didn't record the run")
	f4.queue_free()
	Engine.unregister_singleton("MeldStore")
	fs.free()
	Entitlement.force = null
	MeldSprite.reduce_motion = false
	f.queue_free()
	await process_frame
	print("entitlement_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
