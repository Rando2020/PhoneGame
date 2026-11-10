class_name Playtest
## Playtest builds (pass 22): a hidden menu and a private session log, on only
## when the build carries the "playtest" feature tag (the desktop presets in
## export_presets.cfg; the iOS release preset doesn't). Nothing here changes
## play, and nothing is ever sent anywhere: the log is one JSON line per round
## in user://playtest.log, on this machine only.

const LOG_PATH := "user://playtest.log"
const CATS := ["fifteen", "pair", "run", "flush"]

static var forced = null            ## tests: true/false overrides the feature tag
static var session := ""            ## this launch's id (its start time)
static var _start := {}             ## the round in progress: what it was when it began


static func enabled() -> bool:
	return bool(forced) if forced != null else OS.has_feature("playtest")


## Logging: a playtest build, and the player hasn't turned it off (Settings).
static func log_on() -> bool:
	return enabled() and JS.truthy(Achv.load_store().get("playtest_log", true))


static func set_log(on: bool) -> void:
	var m := Achv.load_store().duplicate(true)
	m["playtest_log"] = on
	Achv.save_store(m)


static func _session() -> String:
	if session == "":
		session = str(int(Time.get_unix_time_from_system()))
	return session


## What a round is: "spoiler", "shortage:<cat>", "twist:<id>" or "plain".
static func kind_of(run: CribRun) -> String:
	if run.is_boss():
		return "spoiler"
	var sh = run.shortage()
	if sh != null:
		return "shortage:" + str(sh)
	var tw = run.twist()
	return "twist:" + str(tw.id) if tw != null else "plain"


## A round's first deal: remember what it is, the tally so far, and the clock.
static func round_start(run: CribRun, now_ms := -1) -> void:
	if not log_on():
		return
	_start = {"kind": kind_of(run), "act": run.act, "round": run.round,
		"cats": run.cat_points.duplicate(), "t": now_ms if now_ms >= 0 else Time.get_ticks_msec()}


## The round is over: one line in the log. Returns the entry (tests), or {}.
static func round_end(run: CribRun, rd: CribRound, now_ms := -1) -> Dictionary:
	if not log_on() or _start.is_empty():
		return {}
	var mix := {}
	for k in CATS:
		mix[k] = float(run.cat_points.get(k, 0)) - float(_start.cats.get(k, 0))
	var e := {"session": _session(), "act": _start.act, "round": _start.round, "kind": _start.kind,
		"mix": mix, "secs": ((now_ms if now_ms >= 0 else Time.get_ticks_msec()) - int(_start.t)) / 1000.0,
		"mulligans": maxi(0, rd.start_mulligans - rd.mulligans_left), "cleared": rd.won}
	_start = {}
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(LOG_PATH) else FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(JSON.stringify(e))
		f.close()
	return e


## Every logged round (all sessions), oldest first.
static func entries() -> Array:
	var out := []
	if not FileAccess.file_exists(LOG_PATH):
		return out
	for line in FileAccess.get_file_as_string(LOG_PATH).split("\n"):
		if line.strip_edges() == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary:
			out.append(d)
	return out


static func clear_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))


static func _lead(mix: Dictionary) -> String:
	var best := ""
	for k in CATS:
		if best == "" or float(mix.get(k, 0)) > float(mix.get(best, 0)):
			best = k
	return best if float(mix.get(best, 0)) > 0.0 else "none"


## The numbers PLAYTEST.md's questions point at, for a list of entries:
##   rounds, cleared_pct, avg_secs, mulligans_per_round,
##   by kind ("twist", "shortage", "plain", "spoiler"): rounds, cleared_pct, avg_secs,
##   lead_changes_pct: between consecutive non-Spoiler rounds of a run, how
##   often the leading category changed (the sims' autopilot number, from play).
static func summary(list: Array) -> Dictionary:
	var s := {"rounds": list.size(), "cleared_pct": 0.0, "avg_secs": 0.0, "mulligans_per_round": 0.0,
		"by_kind": {}, "lead_changes_pct": 0.0, "transitions": 0}
	if list.is_empty():
		return s
	var won := 0
	var secs := 0.0
	var mull := 0
	for e in list:
		won += 1 if e.cleared else 0
		secs += float(e.secs)
		mull += int(e.mulligans)
		var k := String(e.kind).get_slice(":", 0)
		var b: Dictionary = s.by_kind.get(k, {"rounds": 0, "won": 0, "secs": 0.0})
		b.rounds += 1
		b.won += 1 if e.cleared else 0
		b.secs += float(e.secs)
		s.by_kind[k] = b
	for k in s.by_kind:
		var b: Dictionary = s.by_kind[k]
		s.by_kind[k] = {"rounds": b.rounds, "cleared_pct": snappedf(100.0 * b.won / b.rounds, 0.1), "avg_secs": snappedf(b.secs / b.rounds, 0.1)}
	s.cleared_pct = snappedf(100.0 * won / list.size(), 0.1)
	s.avg_secs = snappedf(secs / list.size(), 0.1)
	s.mulligans_per_round = snappedf(float(mull) / list.size(), 0.01)
	# lead changes: consecutive plain/twist/shortage rounds of one run (a run
	# restarts when act and round go back to 1-1, or the session changes)
	var prev = null
	var trans := 0
	var changed := 0
	for e in list:
		if String(e.kind) == "spoiler":
			continue
		var new_run: bool = prev == null or e.session != prev.session or (int(e.act) * 10 + int(e.round)) <= (int(prev.act) * 10 + int(prev.round))
		if not new_run:
			trans += 1
			if _lead(e.mix) != _lead(prev.mix):
				changed += 1
		prev = e
	s.transitions = trans
	s.lead_changes_pct = snappedf(100.0 * changed / trans, 0.1) if trans > 0 else 0.0
	return s


static func session_entries() -> Array:
	return entries().filter(func(e): return String(e.get("session", "")) == _session())
