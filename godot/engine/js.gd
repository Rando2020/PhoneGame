class_name JS
extends RefCounted
## JavaScript semantics the engine depends on. Porting "line for line" is only
## safe if these match, and several of them differ from GDScript by default:
##
##  - JS `a || b` treats 0, "", null and false as missing. `a ?? b` only null.
##  - Math.round rounds halves UP (-2.5 -> -2). GDScript round() rounds away
##    from zero.
##  - Array.prototype.sort is stable. Array.sort_custom is not. Ties in keep
##    EV are common, so an unstable sort changes which keep is "best".
##  - Objects with integer-like keys iterate in ascending numeric order.
##    Dictionaries iterate in insertion order.
##  - `===` on objects is identity. `==` on Dictionaries compares contents.

## Stands in for Math.random. Seeded from the clock in play; tests replace it
## with a fixed seed so the unseeded code paths are reproducible too.
static var unseeded: JsRng = JsRng.new((int(Time.get_unix_time_from_system() * 1000.0) & 0xFFFFFFFF) | 1)


static func rand() -> float:
	return unseeded.next()


static func truthy(v) -> bool:
	if v == null:
		return false
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return v != ""
	return true


## JS: d.k || fallback
static func or_(d: Dictionary, k: String, fallback):
	var v = d.get(k)
	return v if truthy(v) else fallback


## JS: d.k ?? fallback
static func nn(d: Dictionary, k: String, fallback):
	var v = d.get(k)
	return fallback if v == null else v


static func round_(x: float) -> int:
	return int(floor(x + 0.5))


static func is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Number to string the way a JS template literal prints it (3, not 3.0).
static func num_str(x) -> String:
	if typeof(x) == TYPE_FLOAT and x == floor(x) and absf(x) < 1e15:
		return str(int(x))
	return str(x)


## cShuf: Fisher-Yates driven by the given rng, or Math.random when null.
static func shuffle(a: Array, rng: JsRng = null) -> Array:
	var r: JsRng = rng if rng != null else unseeded
	for i in range(a.size() - 1, 0, -1):
		var j := int(floor(r.next() * (i + 1)))
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


## Keys of a dictionary with integer keys, in the order a JS object would give.
static func num_keys(d: Dictionary) -> Array:
	var ks := d.keys()
	ks.sort()
	return ks


## Stable sort, descending by key_fn. Mirrors `arr.sort((a,b) => key(b)-key(a))`.
static func stable_sort_desc(arr: Array, key_fn: Callable) -> Array:
	var dec := []
	for i in arr.size():
		dec.append([key_fn.call(arr[i]), i, arr[i]])
	dec.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1] < b[1])
	var out := []
	for d in dec:
		out.append(d[2])
	return out


## Identity search, for places the JS relies on `===` against objects.
static func index_same(arr: Array, x) -> int:
	for i in arr.size():
		if is_same(arr[i], x):
			return i
	return -1


static func pop_or_null(a: Array):
	return a.pop_back() if not a.is_empty() else null


## Every k-combination of range(n), in the order the JS recursion visits them.
static func combos(n: int, k: int) -> Array:
	var out := []
	_combo_rec(n, k, 0, [], out)
	return out


static func _combo_rec(n: int, k: int, start: int, chosen: Array, out: Array) -> void:
	if chosen.size() == k:
		out.append(chosen.duplicate())
		return
	for i in range(start, n):
		chosen.append(i)
		_combo_rec(n, k, i + 1, chosen, out)
		chosen.pop_back()


## Every permutation of arr, in the order CribRun.bestOrder's recursion visits them.
static func permutations(arr: Array) -> Array:
	var out := []
	_perm_rec(arr, [], out)
	return out


static func _perm_rec(arr: Array, cur: Array, out: Array) -> void:
	if arr.is_empty():
		out.append(cur)
		return
	for i in arr.size():
		var rest := arr.slice(0, i) + arr.slice(i + 1)
		_perm_rec(rest, cur + [arr[i]], out)


## Shallow copy, the equivalent of Object.assign({}, c).
static func copy(d: Dictionary) -> Dictionary:
	return d.duplicate(false)
