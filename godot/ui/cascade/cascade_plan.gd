class_name CascadePlan
extends RefCounted
## The count cascade as data. Port of web/cascade.js cribCascade's sequencing,
## minus the DOM. Pure: same result in, same beats out, nothing animated here.
## CascadeView plays the beats; tests check them against the engine.
##
## Beat: {kind, label, value, number, cards, mult_line, ms}
##   number    = what the big counter shows once this beat lands
##   ms        = base duration at 1x speed (CascadeView divides by speed)
##
## Order: events -> levels -> gilded -> cut -> blocked -> charm chain -> slam.
## DIVERGES FROM THE WEB ON PURPOSE: cascade.js levelStep jumps straight to
## multStep, so any hand with a level bonus skips gilded/cut/blocked and the
## whole charm chain (917 of 1794 fixture deals). Here every step plays.

## Score tiers: a hand at 3x pace must FEEL different from one at pace.
const TIERS := [
	{"at": 0.00, "word": "", "cls": ""},
	{"at": 0.55, "word": "SOLID", "cls": "t-ok"},
	{"at": 1.20, "word": "STRONG", "cls": "t-good"},
	{"at": 2.00, "word": "HUGE", "cls": "t-big"},
	{"at": 3.20, "word": "MASSIVE", "cls": "t-max"},
]


static func tier_for(ratio: float) -> Dictionary:
	var t: Dictionary = TIERS[0]
	for x in TIERS:
		if ratio >= x.at:
			t = x
	return t


static func signed(v) -> String:
	var s := JS.num_str(v)
	return ("\u2212" + s.substr(1)) if s.begins_with("-") else ("+" + s)


static func mult_line(base, mult: float) -> String:
	return "%s \u00d7 %.2f" % [JS.num_str(base), mult]


static func _beat(kind: String, label: String, value: String, number: int, ms: int,
		cards: Array = [], ml := "") -> Dictionary:
	return {"kind": kind, "label": label, "value": value, "number": number,
		"cards": cards, "mult_line": ml, "ms": ms}


## res: CribRound.commit() result. rd: the round (target, mods, score after commit).
## keep_rank: CribRound.keep_rank() taken BEFORE commit, or null.
static func build(res: Dictionary, rd, keep_rank = null) -> Dictionary:
	var beats := []
	var running = 0
	for e in res.events:
		running += e.points
		beats.append(_beat(e.kind, e.label, signed(e.points), JS.round_(running), 380, e.cards))
	if res.events.is_empty():
		beats.append(_beat("zero", "No score", "0", 0, 380))
	if JS.truthy(res.get("levelBonus")):
		running += res.levelBonus
		beats.append(_beat("level", "Category levels", signed(res.levelBonus), JS.round_(running), 460))
	var shown: int = JS.round_(running)
	if JS.truthy(res.get("gildBonus")):
		beats.append(_beat("gild", "Gilded cards", signed(res.gildBonus), shown, 400))
	if JS.truthy(res.get("cutGain")):
		beats.append(_beat("cut", "From the cut", signed(res.cutGain), shown, 420))
	if JS.truthy(res.get("suppressed")):
		beats.append(_beat("block", "%s blocked" % res.get("suppressedBy", "Spoiler"),
			"\u2212" + JS.num_str(res.suppressed), shown, 520))
	var steps: Array = res.get("steps", [])
	if not steps.is_empty():
		beats.append(_beat("chain", "Marks and bonuses", "", int(res.baseOnly), 300, [],
			JS.num_str(res.baseOnly)))
		for st in steps:
			beats.append(_beat("charm", st.name, signed(st.gain), int(st.total), 300, [],
				mult_line(st.base, st.mult)))
	beats.append(_beat("slam", "", "", int(res.total), 620, [], mult_line(res.base, res.mult)))

	var pace: float = float(rd.target) / (CribData.DEALS + rd.mods.dealBonus)
	var ratio: float = res.total / maxf(1.0, pace)
	var lines := []
	if keep_rank != null and keep_rank.get("rank"):
		if keep_rank.rank == 1:
			lines.append({"text": "Best possible keep.", "cls": "green"})
		else:
			var t := "Keep ranked %d of %d by expected value" % [keep_rank.rank, keep_rank.of]
			if keep_rank.get("best") != null:
				t += "  (best expected %.1f)" % keep_rank.best.ev
			lines.append({"text": t, "cls": "gold" if keep_rank.rank <= 3 else "dim"})
	# "I'd have lost without that": say it out loud
	if JS.truthy(res.get("crossedTarget")):
		var clutch := ""
		if res.scoreBefore + res.handOnly < rd.target:
			clutch = "THE CUT SAVED IT"
		else:
			var best = null
			for k in res.get("contrib", {}):
				if res.scoreBefore + res.total - res.contrib[k] < rd.target and \
						(best == null or res.contrib[k] > res.contrib[best]):
					best = k
			if best != null:
				clutch = "%s SAVED IT" % str(best).to_upper()
		if clutch == "" and JS.truthy(res.get("wasFinalDeal")):
			clutch = "ON THE LAST DEAL"
		# One banner. A clutch line already says the target fell, so it replaces
		# TARGET MET instead of stacking under it (at most 2 footer lines).
		if clutch != "":
			lines.append({"text": clutch, "cls": "clutch"})
		else:
			lines.append({"text": "TARGET MET", "cls": "green"})
	return {"beats": beats, "final": int(res.total), "tier": tier_for(ratio), "ratio": ratio,
		"perfect": res.base >= 29 and not JS.truthy(res.get("levelBonus")), "lines": lines,
		"fired": res.get("fired", []).duplicate()}
