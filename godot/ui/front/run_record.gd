class_name RunRecord
extends RefCounted
## The web's UI-side Meta (cribrogue_ui.js top): runs played, best round, best
## hand, clears, best round per Meldling, and the title's one-line summary.
## Shares the one save with Achv, as the web does.

static func record(run: CribRun, reached: int, score: int) -> Dictionary:
	var m := Achv.load_store()
	m["runs"] = int(m.get("runs", 0)) + 1
	m["bestRound"] = maxi(int(m.get("bestRound", 0)), reached)
	m["bestScore"] = maxi(int(m.get("bestScore", 0)), score)
	if reached >= CribData.ACTS * CribData.ROUNDS:
		m["clears"] = int(m.get("clears", 0)) + 1
	if not (m.get("decks") is Dictionary):
		m["decks"] = {}
	m.decks[run.meldling] = maxi(int(m.decks.get(run.meldling, 0)), reached)
	Achv.save_store(m)
	return m


static func line() -> String:
	var m := Achv.load_store()
	var runs := int(m.get("runs", 0))
	if runs == 0:
		return "No runs yet."
	var best := int(m.get("bestRound", 0))
	var act := int(ceil(float(maxi(best, 1)) / CribData.ROUNDS))
	var rd := (maxi(best, 1) - 1) % CribData.ROUNDS + 1
	var best_txt := "Best Act %d-%d" % [act, rd] if best > 0 else "Best: no round cleared"
	return "Runs %d  ·  %s  ·  Cleared %d  ·  Best hand %d" % [runs, best_txt, int(m.get("clears", 0)), int(m.get("bestScore", 0))]
