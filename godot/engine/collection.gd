class_name Collection
## The charm collection (pass 19): each charm's best state, saved in the Achv
## store under "charms": 0 unseen, 1 seen (offered in a shop), 2 owned
## (bought), 3 won with (owned on a cleared run). States only go up. The
## counts are real: nothing is shown as nearer to done than it is.
## Presentation and meta only: no score, draw or reward depends on it.

const UNSEEN := 0
const SEEN := 1
const OWNED := 2
const WON := 3
const NAMES := ["unseen", "seen", "owned", "won with"]


static func level(id: String) -> int:
	return int(Achv.load_store().get("charms", {}).get(id, 0))


## Raise `id` to `lv` if that's higher. True when it rose (the first time a
## charm reaches lv): the caller may celebrate once.
static func mark(id: String, lv: int) -> bool:
	if id == "" or CribData.charm_by_id(id) == null or level(id) >= lv:
		return false
	var m := Achv.load_store().duplicate(true)   # a copy: only the save persists it
	var c: Dictionary = m.get("charms", {})
	c[id] = lv
	m["charms"] = c
	Achv.save_store(m)
	return true


## Mark many at once (one save), returning the ids that rose.
static func mark_all(ids: Array, lv: int) -> Array:
	var m := Achv.load_store().duplicate(true)
	var c: Dictionary = m.get("charms", {})
	var rose := []
	for id in ids:
		if CribData.charm_by_id(id) != null and int(c.get(id, 0)) < lv:
			c[id] = lv
			rose.append(id)
	if not rose.is_empty():
		m["charms"] = c
		Achv.save_store(m)
	return rose


## How many charms are at `lv` or better.
static func count(lv: int) -> int:
	var n := 0
	for ch in CribData.CHARMS:
		if level(ch.id) >= lv:
			n += 1
	return n


static func total() -> int:
	return CribData.CHARMS.size()
