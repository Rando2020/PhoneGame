class_name Combat
extends RefCounted

## The battle model. No nodes, no UI -- pure state so it can be unit-tested and
## so BattleScreen only has to render it.

class Combatant extends RefCounted:
	var id: String = ""
	var display_name: String = ""
	var max_hp: int = 40
	var hp: int = 40
	var block: int = 0
	var burn: int = 0
	var hex: int = 0
	var thorns: int = 0

	func _init(p_id: String, p_name: String, p_hp: int) -> void:
		id = p_id
		display_name = p_name
		max_hp = p_hp
		hp = p_hp

	func alive() -> bool:
		return hp > 0

	func status_line() -> String:
		var bits: Array = ["BLOCK %d" % block]
		if burn > 0:
			bits.append("BURN %d" % burn)
		if hex > 0:
			bits.append("HEX %d" % hex)
		if thorns > 0:
			bits.append("THORNS %d" % thorns)
		return "   ".join(bits)


signal log_line(text: String)
signal player_changed()
signal enemy_changed()
signal battle_ended(victory: bool)

const BASE_HAND := 8
const BASE_FOCUS := 2

var player: Combatant
var enemy: Combatant
var deck: Array = []
var discard: Array = []
var hand: Array = []
var enemy_hand: Array = []
var focus: int = BASE_FOCUS
var max_focus: int = BASE_FOCUS
var turn: int = 1
var over: bool = false
var pending_intent: Dictionary = {}
var run: RunState


func setup(p_run: RunState, enemy_id: String) -> void:
	run = p_run
	var pdata := CreatureDB.get_data(p_run.meldling)
	player = Combatant.new(p_run.meldling, pdata.get("name", "You"), p_run.max_hp)
	player.hp = p_run.hp
	player.thorns = run.relic_value("thorns_start")

	var edata := CreatureDB.get_data(enemy_id)
	enemy = Combatant.new(enemy_id, edata.get("name", enemy_id), int(edata.get("hp", 44)))

	deck = CardArt.new_deck()
	deck.shuffle()
	discard.clear()
	hand.clear()
	enemy_hand.clear()

	max_focus = BASE_FOCUS + run.relic_value("focus_bonus")
	focus = max_focus
	turn = 1
	over = false

	for i in hand_size():
		hand.append(_draw_card())
	for i in 8:
		enemy_hand.append(_draw_card())
	_roll_intent()


func hand_size() -> int:
	return BASE_HAND + run.relic_value("hand_bonus")


func _draw_card() -> Dictionary:
	if deck.is_empty():
		if discard.is_empty():
			return {}
		deck = discard.duplicate()
		deck.shuffle()
		discard.clear()
		log_line.emit("The deck runs out — the discard is reshuffled.")
	return deck.pop_back()


func draw_to_hand(n: int = 1) -> Array:
	var got: Array = []
	for i in n:
		var c := _draw_card()
		if c.is_empty():
			break
		hand.append(c)
		got.append(c)
	return got


# ------------------------------------------------------------------ damage
func _attack(src: Combatant, dst: Combatant, amount: int) -> int:
	var amt: int = maxi(0, amount - src.hex)
	var absorbed: int = mini(dst.block, amt)
	dst.block -= absorbed
	var through: int = amt - absorbed
	dst.hp = maxi(0, dst.hp - through)
	if dst.thorns > 0 and through > 0:
		src.hp = maxi(0, src.hp - dst.thorns)
		log_line.emit("%s takes %d from Thorns." % [src.display_name, dst.thorns])
	return through


# ------------------------------------------------------------------ melds
## Returns { action, damage, block, text, offensive }
func play_meld(cards: Array) -> Dictionary:
	var verdict := MeldRules.classify(cards)
	if not verdict.valid or over:
		return {}

	var n: int = cards.size()
	var result := {"action": verdict.action, "damage": 0, "block": 0,
			"offensive": true, "text": ""}

	match verdict.kind:
		MeldRules.Kind.PAIR:
			var b: int = 6 + n + run.relic_value("brace_bonus")
			player.block += b
			result.block = b
			result.offensive = false
			result.text = "BRACE — %d Block." % b

		MeldRules.Kind.RUN2:
			var extra: int = 2 + run.relic_value("draw_bonus")
			draw_to_hand(extra)
			focus += 1
			result.offensive = false
			result.text = "PREP — drew %d, +1 Focus." % extra

		MeldRules.Kind.RUN:
			var dmg: int = 5 * n + 3 * (n - 3) + run.relic_value("strike_bonus")
			result.damage = _attack(player, enemy, dmg)
			result.text = "STRIKE — %d damage." % result.damage

		MeldRules.Kind.SET:
			var dmg2: int = 4 * n
			var burn: int = 2 + run.relic_value("burn_bonus")
			result.damage = _attack(player, enemy, dmg2)
			enemy.burn += burn
			result.text = "RALLY — %d damage, %d Burn." % [result.damage, burn]

		MeldRules.Kind.GRAND:
			var dmg3: int = 26 + run.relic_value("strike_bonus")
			result.damage = _attack(player, enemy, dmg3)
			enemy.hex += 3
			player.block += 8
			result.block = 8
			result.text = "GRAND MELD — %d damage, 3 Hex, 8 Block." % result.damage

	for c in cards:
		discard.append(c)
	focus -= 1
	log_line.emit(result.text)
	player_changed.emit()
	enemy_changed.emit()
	_check_end()
	return result


## Pull cards out of the model hand by index (highest-first, so indices hold).
func take_from_hand(indices: Array) -> Array:
	var idx: Array = indices.duplicate()
	idx.sort()
	idx.reverse()
	var out: Array = []
	for i in idx:
		if i >= 0 and i < hand.size():
			out.push_front(hand[i])
			hand.remove_at(i)
	return out


func discard_card(index: int) -> Dictionary:
	if index < 0 or index >= hand.size() or over:
		return {}
	var c: Dictionary = hand[index]
	hand.remove_at(index)
	discard.append(c)
	return c


func spend_focus_to_cycle() -> void:
	focus -= 1
	draw_to_hand(1 + run.relic_value("draw_bonus"))


# ------------------------------------------------------------------ turns
func _roll_intent() -> void:
	var kinds := ["STRIKE", "BRACE", "RALLY"]
	if turn % 3 == 0:
		kinds.append("HEX")
	var tier: int = int(CreatureDB.get_data(enemy.id).get("tier", 1))
	var pick: String = kinds[randi() % kinds.size()]
	var amount: int = 0
	match pick:
		"STRIKE":
			amount = 6 + tier * 3 + turn
		"BRACE":
			amount = 6 + tier * 2
		"RALLY":
			amount = 4 + tier * 2
		"HEX":
			amount = 2
	pending_intent = {"kind": pick, "amount": amount}


func intent_text() -> String:
	match pending_intent.get("kind", ""):
		"STRIKE": return "INTENT: STRIKE for %d" % pending_intent.amount
		"BRACE": return "INTENT: BRACE %d Block" % pending_intent.amount
		"RALLY": return "INTENT: RALLY %d + Burn" % pending_intent.amount
		"HEX": return "INTENT: HEX %d" % pending_intent.amount
	return "INTENT: ?"


func end_turn() -> Array:
	## Returns a list of event dictionaries the screen can animate through.
	if over:
		return []
	var events: Array = []

	# player end-of-turn statuses
	if player.burn > 0:
		player.hp = maxi(0, player.hp - player.burn)
		events.append({"t": "burn", "who": "player", "n": player.burn})
		player.burn = maxi(0, player.burn - 1)
	if _check_end():
		return events

	# enemy acts
	var k: String = pending_intent.get("kind", "STRIKE")
	var amt: int = int(pending_intent.get("amount", 6))
	match k:
		"STRIKE":
			var dealt := _attack(enemy, player, amt)
			events.append({"t": "hit", "who": "player", "n": dealt})
		"BRACE":
			enemy.block += amt
			events.append({"t": "block", "who": "enemy", "n": amt})
		"RALLY":
			var dealt2 := _attack(enemy, player, amt)
			player.burn += 2
			events.append({"t": "hit", "who": "player", "n": dealt2})
			events.append({"t": "burn_applied", "who": "player", "n": 2})
		"HEX":
			player.hex += amt
			events.append({"t": "hex", "who": "player", "n": amt})

	# enemy end-of-turn statuses
	if enemy.burn > 0:
		enemy.hp = maxi(0, enemy.hp - enemy.burn)
		events.append({"t": "burn", "who": "enemy", "n": enemy.burn})
		enemy.burn = maxi(0, enemy.burn - 1)

	# decay
	player.block = int(player.block * 0.5)
	enemy.block = int(enemy.block * 0.5)
	player.hex = maxi(0, player.hex - 1)
	enemy.hex = maxi(0, enemy.hex - 1)

	turn += 1
	focus = max_focus
	var refill: int = maxi(0, hand_size() - hand.size())
	draw_to_hand(refill)
	_roll_intent()

	player_changed.emit()
	enemy_changed.emit()
	_check_end()
	return events


func _check_end() -> bool:
	if over:
		return true
	if not enemy.alive():
		over = true
		battle_ended.emit(true)
		return true
	if not player.alive():
		over = true
		battle_ended.emit(false)
		return true
	return false


func sync_to_run() -> void:
	run.hp = player.hp
