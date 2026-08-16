class_name CreatureDB
extends RefCounted

## Roster metadata. Art lives in assets/meldlings/<id>_<anim>.png.
## Stats here are placeholders sized for the First Blood slice -- tune them
## against your real combat math, or move them into data/meldlings.json.

const ROSTER := {
	"pip": {
		"name": "Pip",
		"kind": "meldling",
		"suit": "S",
		"hp": 60,
		"blurb": "Cautious. Bonus Block when it BRACEs on spades.",
	},
	"thump": {
		"name": "Thump",
		"kind": "meldling",
		"suit": "H",
		"hp": 72,
		"blurb": "Stout. Heals a little whenever a RALLY lands.",
	},
	"clover": {
		"name": "Clover",
		"kind": "meldling",
		"suit": "C",
		"hp": 58,
		"blurb": "Patient. PREP carries an extra card into the next turn.",
	},
	"facet": {
		"name": "Facet",
		"kind": "meldling",
		"suit": "D",
		"hp": 54,
		"blurb": "Sharp. STRIKE scales harder with run length.",
	},
	"deadwood": {
		"name": "Deadwood",
		"kind": "enemy",
		"hp": 44,
		"tier": 1,
		"blurb": "Punishes a cluttered hand. Grows with your unplayed cards.",
	},
	"shuffler": {
		"name": "The Shuffler",
		"kind": "enemy",
		"hp": 52,
		"tier": 1,
		"blurb": "Reorders the shared deck. Denies the card you were waiting on.",
	},
	"jokester": {
		"name": "Jokester",
		"kind": "elite",
		"hp": 88,
		"tier": 2,
		"blurb": "Breaks a rule each turn. Sometimes in your favour.",
	},
	"kingpin": {
		"name": "Kingpin",
		"kind": "boss",
		"hp": 160,
		"tier": 3,
		"blurb": "Melds against you using the same deck. Holds the high cards.",
	},
}


static func get_data(id: String) -> Dictionary:
	return ROSTER.get(id, {})


static func display_name(id: String) -> String:
	return ROSTER.get(id, {}).get("name", id.capitalize())


static func ids_of_kind(kind: String) -> Array:
	var out: Array = []
	for id in ROSTER:
		if ROSTER[id].get("kind", "") == kind:
			out.append(id)
	return out


static func meldlings() -> Array:
	return ids_of_kind("meldling")


static func enemies() -> Array:
	return ids_of_kind("enemy")


## Suit -> starter Meldling, so a run can theme itself around a suit.
static func for_suit(suit: String) -> String:
	for id in meldlings():
		if ROSTER[id].get("suit", "") == suit:
			return id
	return "pip"


## The music track a given encounter should use.
static func music_for(id: String) -> String:
	match ROSTER.get(id, {}).get("kind", ""):
		"boss": return "bgm_boss"
		"elite": return "bgm_boss"
		_: return "bgm_battle"
