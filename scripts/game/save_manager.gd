class_name SaveManager
extends RefCounted

## Persistent progress between runs: Essence and the capped Vitality upgrade,
## plus audio settings. Stored in user:// so it survives reinstalls of the build.

const PATH := "user://meldlings_save.cfg"
const VITALITY_CAP := 10
const VITALITY_STEP := 4          ## +HP per Vitality rank
const VITALITY_COST := 25         ## Essence per rank

static var essence: int = 0
static var vitality: int = 0
static var unlocked: Array = ["pip"]
static var music_volume: float = 0.7
static var sfx_volume: float = 0.9
static var _loaded: bool = false


static func load_game() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	essence = cfg.get_value("progress", "essence", 0)
	vitality = cfg.get_value("progress", "vitality", 0)
	unlocked = cfg.get_value("progress", "unlocked", ["pip"])
	music_volume = cfg.get_value("audio", "music", 0.7)
	sfx_volume = cfg.get_value("audio", "sfx", 0.9)


static func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "essence", essence)
	cfg.set_value("progress", "vitality", vitality)
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)


static func bonus_hp() -> int:
	return vitality * VITALITY_STEP


static func can_buy_vitality() -> bool:
	return vitality < VITALITY_CAP and essence >= vitality_cost()


static func vitality_cost() -> int:
	return VITALITY_COST + vitality * 15


static func buy_vitality() -> bool:
	if not can_buy_vitality():
		return false
	essence -= vitality_cost()
	vitality += 1
	save_game()
	return true


static func add_essence(n: int) -> void:
	essence = maxi(0, essence + n)
	save_game()


static func unlock(id: String) -> void:
	if id not in unlocked:
		unlocked.append(id)
		save_game()


static func is_unlocked(id: String) -> bool:
	return id in unlocked


static func wipe() -> void:
	essence = 0
	vitality = 0
	unlocked = ["pip"]
	save_game()
