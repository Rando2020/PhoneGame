class_name RunState
extends RefCounted

## Everything that lives for the length of one run: the map, where you are on
## it, your Meldling, current HP, and the relics you've picked up.

enum NodeType { BATTLE, ELITE, REST, TREASURE, BOSS }

const TYPE_NAMES := {
	NodeType.BATTLE: "Battle",
	NodeType.ELITE: "Elite",
	NodeType.REST: "Rest",
	NodeType.TREASURE: "Cache",
	NodeType.BOSS: "Boss",
}

const RELICS := [
	{"id": "whetstone", "name": "Whetstone", "text": "STRIKE deals +4 damage.",
		"key": "strike_bonus", "value": 4},
	{"id": "bulwark", "name": "Bulwark", "text": "BRACE grants +4 Block.",
		"key": "brace_bonus", "value": 4},
	{"id": "wideeye", "name": "Wide Eye", "text": "Draw 1 extra card each turn.",
		"key": "draw_bonus", "value": 1},
	{"id": "secondwind", "name": "Second Wind", "text": "Start each battle with +1 Focus.",
		"key": "focus_bonus", "value": 1},
	{"id": "emberpip", "name": "Ember Pip", "text": "RALLY applies +2 Burn.",
		"key": "burn_bonus", "value": 2},
	{"id": "thornmail", "name": "Thornmail", "text": "Start each battle with 3 Thorns.",
		"key": "thorns_start", "value": 3},
	{"id": "deepdeck", "name": "Deep Deck", "text": "Hand size +1.",
		"key": "hand_bonus", "value": 1},
	{"id": "luckycut", "name": "Lucky Cut", "text": "Heal 4 after every battle.",
		"key": "heal_after", "value": 4},
]

var meldling: String = "pip"
var max_hp: int = 60
var hp: int = 60
var essence_earned: int = 0
var relics: Array = []              ## Array[Dictionary]
var floor_index: int = 0            ## which row of the map you're on
var node_index: int = 0             ## which node in that row
var visited: Array = []             ## Array[Vector2i]
var map: Array = []                 ## Array[Array[Dictionary]]
var current_enemy: String = "deadwood"
var last_result: String = ""


func start(p_meldling: String) -> void:
	meldling = p_meldling
	var data := CreatureDB.get_data(p_meldling)
	max_hp = int(data.get("hp", 60)) + SaveManager.bonus_hp()
	hp = max_hp
	essence_earned = 0
	relics.clear()
	visited.clear()
	floor_index = 0
	node_index = 0
	last_result = ""
	_generate_map()


# ------------------------------------------------------------------ map
func _generate_map(rows: int = 7) -> void:
	map.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for r in rows:
		var count: int = 1 if r == 0 or r == rows - 1 else rng.randi_range(2, 3)
		var row: Array = []
		for c in count:
			row.append({"type": _pick_type(r, rows, rng), "enemy": "", "seen": false})
		map.append(row)

	# link each node forward to 1-2 nodes in the next row
	for r in map.size() - 1:
		for c in map[r].size():
			var links: Array = []
			var next_n: int = map[r + 1].size()
			var base: int = clampi(int(round(float(c) / maxi(1, map[r].size() - 1) * (next_n - 1))), 0, next_n - 1)
			links.append(base)
			if rng.randf() < 0.55:
				var alt: int = clampi(base + (1 if rng.randf() < 0.5 else -1), 0, next_n - 1)
				if alt not in links:
					links.append(alt)
			map[r][c]["links"] = links
	if not map.is_empty():
		map[-1][0]["links"] = []

	# assign enemies
	var basics := CreatureDB.enemies()
	for r in map.size():
		for c in map[r].size():
			var t: int = map[r][c]["type"]
			match t:
				NodeType.BOSS:
					map[r][c]["enemy"] = "kingpin"
				NodeType.ELITE:
					map[r][c]["enemy"] = "jokester"
				NodeType.BATTLE:
					map[r][c]["enemy"] = basics[rng.randi() % basics.size()]


func _pick_type(r: int, rows: int, rng: RandomNumberGenerator) -> int:
	if r == 0:
		return NodeType.BATTLE
	if r == rows - 1:
		return NodeType.BOSS
	if r == rows - 2:
		return NodeType.REST
	var roll := rng.randf()
	if r >= 3 and roll < 0.22:
		return NodeType.ELITE
	if roll < 0.40:
		return NodeType.TREASURE
	if roll < 0.55:
		return NodeType.REST
	return NodeType.BATTLE


func current_node() -> Dictionary:
	if floor_index >= map.size() or node_index >= map[floor_index].size():
		return {}
	return map[floor_index][node_index]


func reachable_from(r: int, c: int) -> Array:
	if r >= map.size() or c >= map[r].size():
		return []
	return map[r][c].get("links", [])


func advance_to(r: int, c: int) -> void:
	floor_index = r
	node_index = c
	visited.append(Vector2i(r, c))


func is_finished() -> bool:
	return floor_index >= map.size() - 1 and Vector2i(floor_index, node_index) in visited


# ------------------------------------------------------------------ relics
func relic_value(key: String) -> int:
	var total := 0
	for r in relics:
		if r.get("key", "") == key:
			total += int(r.get("value", 0))
	return total


func has_relic(id: String) -> bool:
	for r in relics:
		if r.get("id", "") == id:
			return true
	return false


func add_relic(relic: Dictionary) -> void:
	relics.append(relic)


func offer_relics(count: int = 3) -> Array:
	var pool: Array = []
	for r in RELICS:
		if not has_relic(r["id"]):
			pool.append(r)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


# ------------------------------------------------------------------ hp
func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)


func damage(n: int) -> void:
	hp = maxi(0, hp - n)


func is_dead() -> bool:
	return hp <= 0
