extends SceneTree
## Calibration, not a suite test: the autopilot plays N runs and writes a real
## playtest.log through Playtest's own hooks (no shop, best-EV keeps). Then
## tools/playtest_report.py on that log should match the sims' autopilot
## numbers if the log measures what the sims measure.
##   godot --headless --path godot --script res://tests/bot_log.gd -- N OUT
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 200
	var out := String(args[1]) if args.size() > 1 else "/tmp/bot_playtest.log"
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	Playtest.forced = true
	Playtest.clear_log()
	var chars := ["pip", "thump", "clover", "facet"]
	var t := 0
	for i in n:
		var who: String = chars[i % chars.size()]
		var r := CribRun.new(who, Meta.STREETS[0], null, 9100 + i)
		r.wager_at = {}
		for guard in 40:
			Playtest.round_start(r, t)
			var d := CribRound.new(r)
			while d.new_deal() != null:
				d.commit(d.best_keep_ev().idx)
				if d.score >= d.target or d.deals_left <= 0:
					break
			d.settle()
			t += 60000
			Playtest.round_end(r, d, t)
			if not d.won or r.advance():
				break
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(Playtest.LOG_PATH))
	f.close()
	Playtest.clear_log()
	print("bot_log: %d runs -> %s" % [n, out])
	quit()
