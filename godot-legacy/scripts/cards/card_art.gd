class_name CardArt
extends RefCounted

## Central lookup for every card texture.
## Base art is 70x98 px pixel art -- always render with NEAREST filtering.

const DIR := "res://assets/cards/"
const BASE_W := 70
const BASE_H := 98

const RANK_LABELS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_LETTERS := ["S", "H", "C", "D"]
const SUIT_NAMES := ["Spades", "Hearts", "Clubs", "Diamonds"]

## main.gd / rummy_rules.gd store suits as Unicode pips, so accept those too.
const SUIT_SYMBOLS := {"S": "\u2660", "H": "\u2665", "C": "\u2663", "D": "\u2666"}
const SYMBOL_TO_LETTER := {"\u2660": "S", "\u2665": "H", "\u2663": "C", "\u2666": "D"}

static var _cache: Dictionary = {}


static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Accepts an int index (0..3), a letter ("S"/"H"/"C"/"D"),
## or a Unicode pip ("\u2660"/"\u2665"/"\u2663"/"\u2666") as used by main.gd.
static func suit_letter(suit) -> String:
	if suit is int:
		return SUIT_LETTERS[suit % 4]
	var s := str(suit)
	if SYMBOL_TO_LETTER.has(s):
		return SYMBOL_TO_LETTER[s]
	s = s.to_upper()
	if s.length() > 1:
		s = s.substr(0, 1)
	return s if s in SUIT_LETTERS else "S"


## The pip character, for text output that has to match the existing UI.
static func suit_symbol(suit) -> String:
	return SUIT_SYMBOLS[suit_letter(suit)]


## Convert a card from main.gd form ({rank, suit: "\u2665"}) to this module's form.
static func from_legacy(card: Dictionary) -> Dictionary:
	return {"rank": int(card.get("rank", 1)), "suit": suit_letter(card.get("suit", "S"))}


## Convert back, for handing cards to rummy_rules.gd / cpu_player.gd.
static func to_legacy(card: Dictionary) -> Dictionary:
	return {"rank": int(card.get("rank", 1)), "suit": suit_symbol(card.get("suit", "S"))}


static func from_legacy_hand(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(from_legacy(c))
	return out


static func to_legacy_hand(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(to_legacy(c))
	return out


static func suit_index(suit) -> int:
	if suit is int:
		return suit % 4
	return SUIT_LETTERS.find(suit_letter(suit))


static func rank_label(rank: int) -> String:
	return RANK_LABELS[clampi(rank, 1, 13)]


static func is_red(suit) -> bool:
	return suit_letter(suit) in ["H", "D"]


## rank: 1 = Ace ... 11 = J, 12 = Q, 13 = K
static func face(rank: int, suit) -> Texture2D:
	return _tex(DIR + "card_%s%s.png" % [rank_label(rank), suit_letter(suit)])


static func back() -> Texture2D:
	return _tex(DIR + "card_back.png")


## kind: "selected" | "valid" | "invalid"
static func frame(kind: String) -> Texture2D:
	return _tex(DIR + "frame_%s.png" % kind)


static func pile_empty() -> Texture2D:
	return _tex(DIR + "pile_empty.png")


static func pile_draw() -> Texture2D:
	return _tex(DIR + "pile_draw.png")


static func card_name(rank: int, suit) -> String:
	return "%s of %s" % [rank_label(rank), SUIT_NAMES[suit_index(suit)]]


## Build a standard 52-card deck as an array of {rank, suit} dictionaries.
static func new_deck() -> Array:
	var deck: Array = []
	for s in SUIT_LETTERS:
		for r in range(1, 14):
			deck.append({"rank": r, "suit": s})
	return deck
