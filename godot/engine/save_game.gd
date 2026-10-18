class_name SaveGame
extends RefCounted
## Save and resume a run exactly, mid-round included.
##
## The engine compares cards and charms by IDENTITY (JS ===): the same card
## object sits in run.cards, the stock, the hand, the Crib and the last count.
## So objects are written once and referenced: cards go into a table ({"$c": i}),
## charms by id ({"$charm": id}), the Meldling's own charm as {"$deck": 1},
## Spoilers by id. An unseeded run's rng IS JS.unseeded; that link is kept too.
## Every script variable of CribRun and CribRound is saved, so new fields are
## covered without touching this file. Plain data goes through var_to_str,
## which keeps ints, floats and dictionary key types exact.

const VERSION := 1
## Rebuilt rather than saved: caches.
const SKIP_ROUND := ["run", "_ev_table", "_ev_dealt", "_ev_stock_n"]

var _cards: Array = []        ## card objects, by table index


static func is_card(v) -> bool:
	return v is Dictionary and v.has("rank") and v.has("suit")


# ------------------------------------------------------------------ encode
func _card_index(c: Dictionary) -> int:
	for i in _cards.size():
		if is_same(_cards[i], c):
			return i
	_cards.append(c)
	return _cards.size() - 1


func _enc(v, run: CribRun):
	if v is Charm:
		if run != null and is_same(v, run.deck_charm):
			return {"$deck": 1}
		return {"$charm": v.id}
	if v is JsRng:
		return {"$rng": v.s}
	if v is Object:
		push_error("SaveGame: can't save object %s" % v)
		return null
	if v is Dictionary:
		if is_card(v):
			return {"$c": _card_index(v)}
		for b in CribData.BOSS_POOL:
			if is_same(v, b):
				return {"$boss": b.id}
		# var_to_str SORTS keys, but the engine breaks ties by insertion order
		# (JS object order: the MVP of a tied round): keep the order as pairs
		var pairs := []
		for k in v:
			pairs.append([k, _enc(v[k], run)])
		return {"$o": pairs}
	if v is Array:
		return v.map(func(x): return _enc(x, run))
	return v


func _fields(o: Object, skip: Array, run: CribRun) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p.name in skip:
			continue
		out[p.name] = _enc(o.get(p.name), run)
	return out


## The whole game state as a string. `rd` may be null (between rounds); `peg`
## (a PegSession, The Play in progress) may be null.
static func dump(run: CribRun, rd: CribRound = null, ui := {}, peg = null) -> String:
	var s := SaveGame.new()
	var d := {"v": VERSION, "ui": ui,
		"unseeded": JS.unseeded.s, "rng_is_unseeded": is_same(run.rng, JS.unseeded),
		"street": run.street.id, "trial": run.trial.id if run.trial != null else null,
		"run": s._fields(run, ["rng", "street", "trial", "deck"], run),
		"rng": run.rng.s,
		"round": s._fields(rd, SKIP_ROUND, run) if rd != null else null,
		"peg": {"play": s._fields(peg.play, ["round"], run), "opp": s._enc(peg.opp, run),
			"mult": peg.mult, "applied": peg.applied} if peg != null else null}
	# the card table last: encoding filled it
	d["cards"] = s._cards.map(func(c):
		var pairs := []
		for k in c:
			pairs.append([k, c[k]])
		return pairs)
	return var_to_str(d)


# ------------------------------------------------------------------ decode
var _deck_charm: Charm = null


func _dec(v):
	if v is Dictionary:
		if v.size() == 1:
			if v.has("$c"):
				return _cards[v["$c"]]
			if v.has("$charm"):
				return CribData.charm_by_id(v["$charm"])
			if v.has("$deck"):
				return _deck_charm
			if v.has("$rng"):
				return JsRng.new(v["$rng"])
			if v.has("$boss"):
				for b in CribData.BOSS_POOL:
					if b.id == v["$boss"]:
						return b
			if v.has("$o"):
				var d := {}
				for p in v["$o"]:
					d[p[0]] = _dec(p[1])
				return d
		var d2 := {}
		for k in v:
			d2[k] = _dec(v[k])
		return d2
	if v is Array:
		return v.map(func(x): return _dec(x))
	return v


## Rebuild [run, round-or-null, ui, peg-or-null]. Restores JS.unseeded as saved.
static func load_(text: String) -> Array:
	var d = str_to_var(text)
	assert(d is Dictionary and d.v == VERSION, "SaveGame: unknown save")
	var s := SaveGame.new()
	s._cards = d.cards.map(func(pairs):
		var c := {}
		for p in pairs:
			c[p[0]] = p[1]
		return c)
	JS.unseeded = JsRng.new(d.unseeded)
	var street: Dictionary = Meta.STREETS[int(d.street) - 1]
	var trial = null
	for t in Meta.TRIALS:
		if t.id == d.trial:
			trial = t
	var run := CribRun.new(d.run.meldling, street, trial, 1)   # its own throwaway rng
	# the Meldling's charm: build it the engine's way; saved refs point at it
	run.deck_charm = null
	run.active_charms()
	s._deck_charm = run.deck_charm
	# A new CribRound shuffles with run.rng and may touch the run (the Levy
	# zeroes Glim): build it FIRST, then lay every saved field over both.
	var rd: CribRound = null
	if d.round != null:
		rd = CribRound.new(run)
		for k in d.round:
			rd.set(k, s._dec(d.round[k]))
		rd.run = run
	for k in d.run:
		if k == "deck_charm":
			continue
		run.set(k, s._dec(d.run[k]))
	run.rng = JS.unseeded if d.rng_is_unseeded else JsRng.new(d.rng)
	if d.run.get("deck_charm") == null:
		run.deck_charm = null      # not built yet when saved: leave it lazy, as it was
	var peg = null
	if d.get("peg") != null and rd != null:
		peg = PegSession.new()
		peg.rd = rd
		peg.opp = s._dec(d.peg.opp)
		peg.mult = d.peg.mult
		peg.applied = d.peg.applied
		peg.play = PegPlay.new(rd, [], [])
		for k in d.peg.play:
			peg.play.set(k, s._dec(d.peg.play[k]))
	return [run, rd, d.ui, peg]
