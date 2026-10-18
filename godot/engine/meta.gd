class_name Meta
extends RefCounted
## Port of web/meta.js data and helpers. The save layer (Store/Achv) is achv.gd.

const ACHIEVEMENTS := [
	{"id": "first_road", "name": "First Road", "text": "Clear an Act.", "hint": "Reach Act 2."},
	{"id": "counted", "name": "Counted", "text": "Score a hand worth 40 or more.", "hint": "One big count."},
	{"id": "spoiled", "name": "Spoiled", "text": "Beat a Spoiler.", "hint": "Survive a boss round."},
	{"id": "twentynine", "name": "Twenty-Nine", "text": "Count the perfect hand.", "hint": "5-5-5-J with the matching 5 cut.", "secret": true},
	{"id": "nineteen", "name": "Nineteen", "text": "Count a hand worth nothing.", "hint": "The score cribbage cannot make."},
	{"id": "his_heels", "name": "His Heels", "text": "Cut a Jack.", "hint": "The starter comes up a knave."},
	{"id": "clutch", "name": "Down to the Cut", "text": "Win a round on the cut alone.", "hint": "Your four cards weren't enough."},
	{"id": "optimal5", "name": "Sharp Eye", "text": "Make the best possible keep 5 times in one run."},
	{"id": "skunk", "name": "Skunked", "text": "Clear a round at triple the target."},
	{"id": "shatter", "name": "Brittle Heart", "text": "Break three marked cards in one run."},
	{"id": "whittled", "name": "Whittled Down", "text": "Finish a round with fewer than 30 cards."},
	{"id": "deep_count", "name": "Deep Count", "text": "Take a Reckoning to level 8."},
	{"id": "hallowed", "name": "Hallowed Hand", "text": "Hold two Hallowed charms at once."},
	{"id": "crib_king", "name": "Crib King", "text": "Score 60 or more from a single Crib."},
	{"id": "long_road", "name": "The Long Road", "text": "Clear a full run.", "hint": "All five Acts."},
	{"id": "street_ii", "name": "Second Street", "text": "Clear a run on Street II."},
	{"id": "street_iii", "name": "Third Street", "text": "Clear a run on Street III."},
]

## Difficulty tiers, named for the rows of a cribbage board.
const STREETS := [
	{"id": 1, "name": "First Street", "text": "The road as it comes.", "mods": {}},
	{"id": 2, "name": "Second Street", "text": "Targets +25%. The Crib scores at half.",
		"mods": {"targetMul": 1.25, "cribHalf": true}},
	{"id": 3, "name": "Third Street", "text": "Spoilers hold rounds 3 and 5.",
		"mods": {"targetMul": 1.25, "extraSpoiler": true}},
	{"id": 4, "name": "Fourth Street", "text": "One fewer charm slot. Marks cost double.",
		"mods": {"targetMul": 1.3, "slots": -1, "extraSpoiler": true, "markCostMul": 2}},
	{"id": 5, "name": "Fifth Street", "text": "Your deck no longer recycles. Run it dry and the round ends.",
		"mods": {"targetMul": 1.35, "slots": -1, "extraSpoiler": true, "noRecycle": true}},
	{"id": 6, "name": "The Turn", "text": "Charms score at half against Spoilers.",
		"mods": {"targetMul": 1.3, "slots": -1, "extraSpoiler": true, "noRecycle": true, "halfCharmBoss": true}},
	{"id": 7, "name": "The Stink Hole", "text": "Clearing early pays nothing extra.",
		"mods": {"targetMul": 1.32, "slots": -1, "extraSpoiler": true, "noRecycle": true,
			"halfCharmBoss": true, "noCashOut": true}},
	{"id": 8, "name": "Skunk Line", "text": "Every Spoiler is Ruinous.",
		"mods": {"targetMul": 1.34, "slots": -1, "extraSpoiler": true, "noRecycle": true,
			"halfCharmBoss": true, "noCashOut": true, "allRuinous": true}},
]

## Preset runs built around one brutal constraint.
const TRIALS := [
	{"id": "pauper", "name": "The Pauper", "deck": "pip",
		"text": "No shop, ever. Only what the deck gives you.", "mods": {"noShop": true}},
	{"id": "onesuit", "name": "One Suit", "deck": "clover",
		"text": "Your deck is fifty-two hearts.", "mods": {"oneSuit": "H", "targetMul": 1.35}},
	{"id": "ascetic", "name": "The Ascetic", "deck": "muggins",
		"text": "Your hand scores at a quarter. The Crib pays four times over.",
		"mods": {"handQuarter": true, "cribQuad": true, "targetMul": 0.4}},
	{"id": "thirteen", "name": "Thirteen", "deck": "facet",
		"text": "Your deck is thirteen cards, recycling constantly.", "mods": {"deckCap": 13}},
	{"id": "court", "name": "The Assessor's Court", "deck": "nib",
		"text": "Clear every target, but never score more than double it.",
		"mods": {"allExact": true, "overBand": 2.0, "targetMul": 0.8}},
	{"id": "famine", "name": "Long Famine", "deck": "thump",
		"text": "Three deals a round, and one mulligan only.",
		"mods": {"dealBonus": -1, "mulliganBonus": -1, "targetMul": 0.75}},
	{"id": "blind", "name": "Blind Man's Count", "deck": "pip",
		"text": "You never see the deck tracker, and the cut is never previewed.",
		"mods": {"hideTracker": true}},
	{"id": "glass", "name": "Glass Road", "deck": "clover",
		"text": "Every card you buy is Brittle.", "mods": {"allBrittle": true}},
]

## Past Act 5, the ladder keeps going.
const ENDLESS_FROM := 26

const MELDLING_UNLOCKS := {
	"pip": null, "thump": null, "clover": null, "facet": null,
	"nib": "twentynine",    # earned by counting the perfect hand
	"muggins": "long_road", # earned by clearing a full run
}

const ASCENDED := {
	"pip": {"of": "pip", "name": "Pip Ascended"},
	"thump": {"of": "thump", "name": "Thump Ascended"},
	"clover": {"of": "clover", "name": "Clover Ascended"},
	"facet": {"of": "facet", "name": "Facet Ascended"},
}

## System unlocks: won from Wagers, never bought.
const SYSTEMS := [
	{"id": "crib_cut", "name": "The Crib's Own Cut",
		"text": "Your Crib gets its own cut card at round end, with its own reveal."},
	{"id": "crib_mult", "name": "The Gathering",
		"text": "The Crib builds a multiplier as you feed it. Matching suits and courts raise it."},
	{"id": "split_cards", "name": "Split Cards",
		"text": "The Stall begins selling cards that are two ranks at once."},
	{"id": "sixth_slot", "name": "The Sixth Slot",
		"text": "One more charm slot, for the rest of time."},
	{"id": "the_play", "name": "The Play",
		"text": "After each count, you and the Spoiler peg your cards toward 31 for bonus points."},
	{"id": "deep_stall", "name": "The Deep Stall",
		"text": "The Stall offers four cards instead of three, and Marks appear more often."},
]

const CARD_BACKS := [
	{"id": "indigo", "name": "Indigo", "cost": 0, "text": "The house back."},
	{"id": "crimson", "name": "Crimson", "cost": 25, "text": "Woven red."},
	{"id": "moss", "name": "Mosswork", "cost": 25, "text": "Rays through green."},
	{"id": "bone", "name": "Bone", "cost": 40, "text": "Pale and plain."},
	{"id": "void", "name": "The Void", "cost": 60, "text": "Chevrons in the dark."},
	{"id": "brass", "name": "Brass", "cost": 80, "text": "Rings of old metal."},
]

const LENSES := [
	{"id": "counter", "name": "Counter's Lens", "cost": 30,
		"text": "Pins the deck tracker open: every rank still live, at a glance."},
	{"id": "crib", "name": "Crib Glass", "cost": 30,
		"text": "Pins your Crib open, so you always see what you've fed it."},
	{"id": "ledger", "name": "The Ledger", "cost": 35,
		"text": "Pins your charms on the table during play."},
	{"id": "odds", "name": "Odds Glass", "cost": 45,
		"text": "Shows how many live cards would improve each keep."},
]


static func pegs_for_run(reached: int, cleared: bool, street: int, deeds: int) -> int:
	var p := reached / 2
	if cleared:
		p += 20 + street * 10
	p += deeds * 5
	return p


## Local calendar date as YYYY-MM-DD. `unix` defaults to now.
static func daily_key(unix := -1.0) -> String:
	var t := Time.get_unix_time_from_system() if unix < 0 else unix
	var local: int = int(t) + Time.get_time_zone_from_system().bias * 60
	var d := Time.get_date_dict_from_unix_time(local)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## FNV-1a over UTF-16 code units, bit-exact with meta.js dailySeed.
static func daily_seed(key: String) -> int:
	var h := 2166136261
	for i in key.length():
		h = h ^ key.unicode_at(i)
		h = (h * 16777619) & 0xFFFFFFFF
	return h
