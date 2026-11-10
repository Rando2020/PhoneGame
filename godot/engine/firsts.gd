class_name Firsts
## First-time celebrations (pass 14, LOOP_AUDIT 10): each fires once ever,
## saved in the Achv store under "firsts". Presentation only: claiming one
## changes no score, no draw and no reward.

const ALL := {
	"spoiler": {"name": "First Spoiler down", "text": "Every act ends with one. You know how now."},
	"act": {"name": "First act cleared", "text": "Four to go. Targets climb from here."},
	"peddler": {"name": "First Peddler buy", "text": "Yours for good. Equip it any time."},
}


static func seen(id: String) -> bool:
	return JS.truthy(Achv.load_store().get("firsts", {}).get(id))


## True the first time only (and saves that it happened).
static func claim(id: String) -> bool:
	if not ALL.has(id) or seen(id):
		return false
	var m := Achv.load_store().duplicate(true)   # a copy: only the save persists it
	var f: Dictionary = m.get("firsts", {})
	f[id] = 1
	m["firsts"] = f
	Achv.save_store(m)
	return true
