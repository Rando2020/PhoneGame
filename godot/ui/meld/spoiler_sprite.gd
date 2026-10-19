class_name SpoilerSprite
extends MeldSprite
## A Spoiler across the table. Same motion as a Meldling; its own art
## (art/spoilers/spoiler_<art>_s<sev>_<pose>.png) and its own reactions:
##   count: stung when the count makes its share of the target anyway (you beat
##          its rule), else smug when its rule took points (res.suppressed > 0)
##   peg:   smug when it pegs in The Play
##   round_won: defeated (holds)   run_lost: gloat (holds)
## Presentation only. No haptics of its own: your Meldling's buzz covers the beat.

const POSES := ["idle", "smug", "stung", "defeated", "gloat"]
const HOLD := {"smug": 1.4, "stung": 1.4, "defeated": 0.0, "gloat": 0.0}

var art := "auditor"
var sev := 1


func _init(boss: Dictionary = {}) -> void:
	super("pip")
	set_boss(boss)


func set_boss(boss: Dictionary) -> void:
	if boss.is_empty():
		return
	art = String(boss.get("art", "auditor"))
	sev = int(boss.get("sev", 1))
	pose = "idle"
	timer = 0.0
	_show()


static func path_for(art_: String, sev_: int, p: String) -> String:
	return "res://art/spoilers/spoiler_%s_s%d_%s.png" % [art_, sev_, p]


func _texture_for(p: String) -> Texture2D:
	var path := path_for(art, sev, p)
	if not ResourceLoader.exists(path):
		path = path_for(art, sev, "idle")
	return load(path) if ResourceLoader.exists(path) else null


func _hold(p: String) -> float:
	return float(HOLD.get(p, 1.2))


func _buzz(_p: String) -> int:
	return 0


## The target share of one deal: the round's target over its starting deals.
static func share(rd: CribRound) -> int:
	return int(ceil(float(rd.target) / maxf(1.0, CribData.DEALS + int(rd.mods.get("dealBonus", 0)))))


static func pose_for(event: String, rd: CribRound = null, res: Dictionary = {}) -> String:
	match event:
		"count":
			if rd != null and int(res.get("total", 0)) >= share(rd):
				return "stung"
			if int(res.get("suppressed", 0)) > 0:
				return "smug"
			return ""
		"peg":
			return "smug"
		"round_won":
			return "defeated"
		"run_lost":
			return "gloat"
	return ""


func on_event(event: String, rd: CribRound = null, res: Dictionary = {}) -> String:
	var p := pose_for(event, rd, res)
	react(p)
	return p
