extends SceneTree
## Writes the content counts the store listing quotes, from the game data, for
## tools/check_listing.py --counts. Prints the path.
##   godot --headless --path godot --script res://tests/listing_counts.gd
func _initialize() -> void:
	var asc := 0
	for k in CribData.DECKS:
		if JS.truthy(CribData.DECKS[k].get("ascended", false)):
			asc += 1
	var out := {
		"charms": CribData.CHARMS.size(), "spoilers": CribData.BOSS_POOL.size(),
		"marks": CribData.ENHANCEMENTS.size(), "deeds": Meta.ACHIEVEMENTS.size(),
		"streets": Meta.STREETS.size(), "trials": Meta.TRIALS.size(),
		"acts": CribData.ACTS, "rounds": CribData.ROUNDS,
		"base_meldlings": CribData.DECKS.size() - asc, "ascended": asc,
		"howto_steps": Menus.TUT_STEPS.size(),
		"mark_names": CribData.ENHANCEMENTS.values().map(func(e): return String(e.name)),
	}
	var f := FileAccess.open("/tmp/listing_counts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print(JSON.stringify(out))
	quit()
