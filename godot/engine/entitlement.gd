class_name Entitlement
## The one place the game asks "is the full game unlocked?" (docs/MONETIZATION.md).
## Free to try: every run stops after act 1 (the first Spoiler beaten), with an
## end card that offers the unlock. One non-consumable purchase, FULL_ID,
## unlocks the rest for good. Nothing paid changes how the game scores.
##
## Where the answer comes from, in order:
##   1. `force` (tests only): true / false.
##   2. The saved flag ("full" in the Achv store): set by a purchase or a
##      restore, so the game stays unlocked offline.
##   3. No store at all (no MeldStore plugin) in a development build (the
##      editor binary, which every test and soak runs under): unlocked, so the
##      whole game stays testable. A shipped build without the plugin stays
##      free-only (it can't sell, so it doesn't give away).
## The store plugin (ios_plugin/meld_store) is an Engine singleton "MeldStore":
##   products() -> Array of {"id", "price"}; purchase(id); restore();
##   signals purchased(id), restored(ids: Array), failed(id, reason).

const FULL_ID := "com.meldlings.full"   ## the App Store product id (MAC_HANDOFF.md, IAP)
const FREE_LAST_ACT := 1                ## free runs stop after this act

static var force = null                 ## tests: true / false; null = real answer


static func store() -> Object:
	return Engine.get_singleton("MeldStore") if Engine.has_singleton("MeldStore") else null


static func full() -> bool:
	if force != null:
		return bool(force)
	if JS.truthy(Achv.load_store().get("full")):
		return true
	return store() == null and OS.has_feature("editor")


## A purchase or restore came through: unlocked for good on this device.
static func grant() -> void:
	var m := Achv.load_store()
	m["full"] = 1
	Achv.save_store(m)


## Free mode: has this run gone as far as it may? True once act 1's last
## round (the first Spoiler) is won, and for any run past act 1.
static func capped(run: CribRun, won_last_round := false) -> bool:
	if full() or run.endless:
		return false
	if run.act > FREE_LAST_ACT:
		return true
	return won_last_round and run.act == FREE_LAST_ACT and run.round == CribData.ROUNDS


## The store's price for the unlock, or "" before it has answered.
static func price() -> String:
	var s := store()
	if s == null or not s.has_method("products"):
		return ""
	for p in s.call("products"):
		if String(p.get("id", "")) == FULL_ID:
			return String(p.get("price", ""))
	return ""


## What the full game adds, from the data (the end card's line).
static func pitch(run: CribRun) -> String:
	var acts := CribData.ACTS - FREE_LAST_ACT
	var bosses := maxi(0, run.boss_plan.size() - FREE_LAST_ACT)
	return "Unlock the full game: %d more acts and %d more Spoilers this run, then %d more streets, %d trials and the Long Count. One purchase. No ads, no account." % [
		acts, bosses, Meta.STREETS.size() - 1, Meta.TRIALS.size()]
