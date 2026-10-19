class_name MeldReact
extends RefCounted
## Which reaction a game event earns. Pure: reads the engine, never changes it,
## never draws from JS.unseeded. MeldSprite plays what this returns.
##
## Events: "deal", "count" (res = the commit's result), "round_won", "run_lost".

const POSES := ["idle", "eager", "nervous", "cheer", "victory", "deflated"]
const SIGNATURE := {"pip": "fifteen", "thump": "slam", "clover": "lucky",
	"facet": "sparkle", "nib": "snip", "muggins": "steal"}
## how long a reaction holds before idle (seconds); <= 0 holds until replaced
const HOLD := {"eager": 1.1, "nervous": 2.4, "cheer": 1.6, "victory": 0.0, "deflated": 0.0,
	"fifteen": 1.6, "slam": 1.4, "lucky": 1.6, "sparkle": 1.6, "snip": 1.4, "steal": 1.6}
## haptic pulse per reaction, in ms (0: none)
const BUZZ := {"cheer": 25, "victory": 70, "fifteen": 25, "slam": 35, "lucky": 25,
	"sparkle": 25, "snip": 25, "steal": 25}


## The sprite set for a Meldling id (ascended ones wear the base art).
static func art_id(meld: String) -> String:
	var base := meld.trim_suffix("_asc")
	if CribData.DECKS.has(meld) and CribData.DECKS[meld].has("art"):
		base = String(CribData.DECKS[meld].art)
	return base if SIGNATURE.has(base) else "pip"


## A count is "big" at a third of the round's target (at least 20).
static func big_count(rd: CribRound) -> int:
	return maxi(20, int(ceil(rd.target / 3.0)))


static func _has_kind(res: Dictionary, kind: String) -> bool:
	for e in res.get("events", []):
		if String(e.get("kind", "")) == kind:
			return true
	return false


## Did this count trigger the Meldling's own rule?
static func signature_hit(meld: String, res: Dictionary, rd: CribRound) -> bool:
	match art_id(meld):
		"pip": return _has_kind(res, "fifteen")
		"thump": return _has_kind(res, "pair")
		"clover": return int(res.get("cutGain", 0)) >= 4
		"facet": return _has_kind(res, "flush")
		"nib": return rd != null and rd.auto_recuts > 0
		"muggins": return rd != null and rd.run != null and rd.run.boss() != null
	return false


## The reaction for an event, or "" for none.
static func pose_for(event: String, meld: String, rd: CribRound = null, res: Dictionary = {}) -> String:
	match event:
		"deal":
			if rd != null and rd.deals_left <= 1 and rd.score < rd.target:
				return "nervous"
			return "eager"
		"count":
			var big: bool = rd != null and int(res.get("total", 0)) >= big_count(rd)
			if signature_hit(meld, res, rd):
				return SIGNATURE[art_id(meld)]
			return "cheer" if big else ""
		"round_won":
			return "victory"
		"run_lost":
			return "deflated"
	return ""
