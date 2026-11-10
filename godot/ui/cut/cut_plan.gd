class_name CutPlan
extends RefCounted
## The cut ceremony as data. Port of CUT_TIERS / cutCeremony (web/cribrogue_ui.js).
## A better card rolls LONGER before it lands, so the wait itself becomes hope.

const TIERS := {
	"cold": {"roll": 520, "word": "", "pips": 0, "shake": 3},
	"okay": {"roll": 780, "word": "OKAY", "pips": 8, "shake": 5},
	"good": {"roll": 1080, "word": "GOOD", "pips": 18, "shake": 8},
	"great": {"roll": 1460, "word": "GREAT", "pips": 30, "shake": 12},
	"perfect": {"roll": 2000, "word": "THE BEST CARD IN THE DECK", "pips": 52, "shake": 18},
}


## Cut quality exactly as the web UI computes it: the live starter scored against
## the stock as it stood BEFORE commit. (The web's pool therefore holds the starter
## twice; kept so tiers match what web players see.) Shared by the screen and tests.
static func quality_like_web(rd, kept: Array, pre_stock: Array) -> Dictionary:
	var starter = rd.live_starter(kept)
	var live: Array = rd.stock
	rd.stock = pre_stock
	var q: Dictionary = rd.cut_quality(kept, starter)
	rd.stock = live
	q["starter"] = starter
	return q


static func build(q: Dictionary) -> Dictionary:
	var t: Dictionary = TIERS.get(q.tier, TIERS.okay)
	var gain: int = q.gain
	var sub := ("+%d from the cut  ·  %d of %d possible" % [gain, q.rank, q.of]) if gain > 0 \
		else ("nothing from the cut  ·  %d of %d possible" % [q.rank, q.of])
	return {"tier": q.tier, "starter": q.starter, "roll": t.roll / 1000.0, "word": t.word,
		"pips": t.pips, "shake": t.shake, "hold": 1.5 if q.tier == "perfect" else 0.78,
		"sub": sub, "sub_gold": gain > 0}
