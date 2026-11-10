class_name NextUnlock
## The nearest real goal, for the run-end card (LOOP_AUDIT.md, item 3): one
## line, from the actual unlock data, never invented.
## In order: something you can buy now at the Peddler; else the Peddler item
## fewest Pegs away; else a locked Meldling and the deed that earns it.


static func line() -> String:
	var pegs := Achv.pegs()
	var items := []
	for b in Meta.CARD_BACKS:
		if not Achv.owns_back(b.id) and int(b.cost) > 0:
			items.append({"name": String(b.name), "cost": int(b.cost), "kind": "card back"})
	for l in Meta.LENSES:
		if not Achv.owns_lens(l.id):
			items.append({"name": String(l.name), "cost": int(l.cost), "kind": "lens"})
	items.sort_custom(func(a, b): return a.cost < b.cost or a.cost == b.cost and a.name < b.name)
	for it in items:
		if it.cost <= pegs:
			return "You can afford %s at the Peddler: %d Pegs, you have %d." % [it.name, it.cost, pegs]
	if not items.is_empty():
		var it: Dictionary = items[0]
		return "Next: %s, %d more Pegs (%d / %d)." % [it.name, it.cost - pegs, pegs, it.cost]
	for id in Meta.MELDLING_UNLOCKS:
		var deed = Meta.MELDLING_UNLOCKS[id]
		if deed != null and not Achv.has(deed):
			for a in Meta.ACHIEVEMENTS:
				if a.id == deed:
					return "Next: %s joins when you earn %s: %s" % [CribData.DECKS[id].name, a.name, a.text]
	return "Every card back and lens is yours."
