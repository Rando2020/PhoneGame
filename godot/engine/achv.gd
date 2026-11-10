class_name Achv
extends RefCounted
## Port of the Store + Achv save layer from web/meta.js.
## One store, one key, one in-memory copy. localStorage becomes user://.
## Set `persist = false` for tests: the store then lives only in memory,
## which is also exactly how the JS behaves under Node (no localStorage).

const SAVE_PATH := "user://meldlings.save"
const SAVE_VERSION := 3

static var persist := true
static var _cache = null


static func _migrate(v: int, m: Dictionary) -> Dictionary:
	if v == 1:
		# Lenses became free pins; carry ownership across as pinned panels
		if m.has("lenses"):
			if not m.has("pins"):
				m["pins"] = {}
			var map := {"counter": "counter", "crib": "crib", "ledger": "ledger"}
			var off: Dictionary = m.get("lensOff", {})
			for k in m.lenses:
				if map.has(k) and not JS.truthy(off.get(k)):
					m.pins[map[k]] = true
		m.erase("lenses")
		m.erase("lensOff")
	elif v == 2:
		m.erase("surplus")
	return m


static func load_store() -> Dictionary:
	if _cache != null:
		return _cache
	var m := {}
	if persist and FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f else null
		if parsed is Dictionary:
			m = parsed
	var v: int = int(m.get("__v", 1))
	while v < SAVE_VERSION:
		m = _migrate(v, m)
		v += 1
	m["__v"] = SAVE_VERSION
	_cache = m
	return m


static func save_store(m: Dictionary) -> void:
	_cache = m
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(m))


static func wipe() -> void:
	_cache = null
	if persist and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _sub(key: String) -> Dictionary:
	var m := load_store()
	if not (m.get(key) is Dictionary):
		m[key] = {}
	return m[key]


static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


static func has(id: String) -> bool:
	return JS.truthy(load_store().get("got", {}).get(id))


static func count() -> int:
	return load_store().get("got", {}).size()


static func grant(id: String) -> bool:
	var got := _sub("got")
	if JS.truthy(got.get(id)):
		return false
	got[id] = _now_ms()
	save_store(load_store())
	return true


static func street_unlocked() -> int:
	return maxi(1, mini(Meta.STREETS.size(), int(JS.or_(load_store(), "street", 1))))


static func unlock_street(n: int) -> void:
	var m := load_store()
	m["street"] = maxi(int(JS.or_(m, "street", 1)), mini(Meta.STREETS.size(), n))
	save_store(m)


static func pegs() -> int:
	return int(JS.or_(load_store(), "pegs", 0))


static func add_pegs(n: int) -> int:
	var m := load_store()
	m["pegs"] = int(JS.or_(m, "pegs", 0)) + n
	save_store(m)
	return m.pegs


static func spend_pegs(n: int) -> bool:
	var m := load_store()
	if int(JS.or_(m, "pegs", 0)) < n:
		return false
	m["pegs"] = int(m.pegs) - n
	save_store(m)
	return true


static func cleared_with(deck: String) -> bool:
	return JS.truthy(load_store().get("cleared", {}).get(deck))


static func mark_cleared(deck: String) -> void:
	_sub("cleared")[deck] = 1
	save_store(load_store())


static func trial_done(id: String) -> bool:
	return JS.truthy(load_store().get("trials", {}).get(id))


static func mark_trial(id: String) -> void:
	_sub("trials")[id] = 1
	save_store(load_store())


static func best_endless() -> int:
	return int(JS.or_(load_store(), "endless", 0))


static func set_endless(n: int) -> void:
	var m := load_store()
	if n > int(JS.or_(m, "endless", 0)):
		m["endless"] = n
		save_store(m)


static func pinned(id: String) -> bool:
	return JS.truthy(load_store().get("pins", {}).get(id))


static func toggle_pin(id: String) -> void:
	var pins := _sub("pins")
	pins[id] = not JS.truthy(pins.get(id))
	save_store(load_store())


static func daily_done(key := ""):
	return load_store().get("daily", {}).get(key if key != "" else Meta.daily_key())


static func record_daily(key: String, result) -> void:
	var daily := _sub("daily")
	daily[key] = result
	# keep a fortnight, not a lifetime
	var keys := daily.keys()
	keys.sort()
	keys = keys.slice(maxi(0, keys.size() - 14))
	var trimmed := {}
	for k in keys:
		trimmed[k] = daily[k]
	var m := load_store()
	m["daily"] = trimmed
	m["dailyStreak"] = streak_from(trimmed)
	save_store(m)


static func streak_from(daily: Dictionary) -> int:
	var n := 0
	var t := Time.get_unix_time_from_system()
	while daily.has(Meta.daily_key(t)) and JS.truthy(daily[Meta.daily_key(t)]):
		n += 1
		t -= 86400.0
	return n


static func daily_streak() -> int:
	return streak_from(load_store().get("daily", {}))


## The systems every player starts with (Meta.STARTER_SYSTEMS); tests of the
## flow without one set this to [].
static var starters: Array = Meta.STARTER_SYSTEMS.duplicate()


static func has_system(id: String) -> bool:
	return starters.has(id) or JS.truthy(load_store().get("systems", {}).get(id))


static func grant_system(id: String) -> bool:
	var sys := _sub("systems")
	if JS.truthy(sys.get(id)):
		return false
	sys[id] = _now_ms()
	save_store(load_store())
	return true


static func locked_systems() -> Array:
	return Meta.SYSTEMS.filter(func(s): return not has_system(s.id))


static func owns_lens(id: String) -> bool:
	return JS.truthy(load_store().get("lenses", {}).get(id))


static func buy_lens(id: String) -> bool:
	var l = null
	for x in Meta.LENSES:
		if x.id == id:
			l = x
	if l == null or owns_lens(id) or not spend_pegs(l.cost):
		return false
	_sub("lenses")[id] = 1
	save_store(load_store())
	return true


static func lens_on(id: String) -> bool:
	if not owns_lens(id):
		return false
	return not JS.truthy(load_store().get("lensOff", {}).get(id))


static func toggle_lens(id: String) -> void:
	var off := _sub("lensOff")
	off[id] = not JS.truthy(off.get(id))
	save_store(load_store())


static func owns_back(id: String) -> bool:
	return id == "indigo" or JS.truthy(load_store().get("backs", {}).get(id))


static func buy_back(id: String) -> bool:
	var b = null
	for x in Meta.CARD_BACKS:
		if x.id == id:
			b = x
	if b == null or owns_back(id) or not spend_pegs(b.cost):
		return false
	_sub("backs")[id] = 1
	save_store(load_store())
	return true


static func active_back() -> String:
	return JS.or_(load_store(), "back", "indigo")


static func set_back(id: String) -> bool:
	if not owns_back(id):
		return false
	load_store()["back"] = id
	save_store(load_store())
	return true


## Last ten runs.
static func log_run(entry: Dictionary) -> void:
	var m := load_store()
	m["history"] = ([entry] + m.get("history", [])).slice(0, 10)
	save_store(m)


static func history() -> Array:
	return load_store().get("history", [])


static func deck_stats() -> Dictionary:
	var by := {}
	for r in history():
		if not by.has(r.deck):
			by[r.deck] = {"runs": 0, "best": 0, "total": 0}
		var d: Dictionary = by[r.deck]
		d.runs += 1
		d.total += r.reached
		d.best = maxi(d.best, r.reached)
	for k in by:
		by[k]["avg"] = "%.1f" % (float(by[k].total) / by[k].runs)
	return by


static func meldling_unlocked(id: String) -> bool:
	var basename := id.replace("_asc", "")
	if Meta.ASCENDED.has(basename) and id.ends_with("_asc"):
		return cleared_with(basename)
	var req = Meta.MELDLING_UNLOCKS.get(id)
	return req == null or has(req)


## Fired from gameplay; returns the list of newly earned achievements.
static func check(evt: String, d: Dictionary = {}) -> Array:
	var got := []
	var g := func(id: String):
		if grant(id):
			got.append(id)
	var t := func(k): return JS.truthy(d.get(k))
	var n := func(k): return d.get(k, 0) if d.get(k) != null else 0
	if evt == "count":
		if n.call("total") >= 40: g.call("counted")
		if n.call("base") >= 29 and t.call("perfect"): g.call("twentynine")
		if d.has("base") and d.base == 0: g.call("nineteen")
		if t.call("cutJack"): g.call("his_heels")
		if t.call("cutSaved"): g.call("clutch")
		if n.call("optimalStreak") >= 5: g.call("optimal5")
	if evt == "round":
		if t.call("won") and n.call("act") >= 1 and n.call("round") >= 5: g.call("spoiled")
		if t.call("won") and n.call("score") >= n.call("target") * 3: g.call("skunk")
		if t.call("won") and d.has("deckSize") and d.deckSize < 30: g.call("whittled")
		if n.call("cribTotal") >= 60: g.call("crib_king")
		if n.call("maxReckoning") >= 8: g.call("deep_count")
		if n.call("hallowed") >= 2: g.call("hallowed")
		if n.call("shattered") >= 3: g.call("shatter")
		if t.call("won") and t.call("actCleared"): g.call("first_road")
	if evt == "run":
		if t.call("cleared"):
			g.call("long_road")
			if n.call("street") >= 2: g.call("street_ii")
			if n.call("street") >= 3: g.call("street_iii")
			unlock_street(n.call("street") + 1)
	return got
