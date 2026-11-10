class_name Charm
extends RefCounted
## One charm. A RefCounted object on purpose: the engine compares charms by
## identity (JS `===`), which Dictionaries would not preserve.
##
## on_event(e: Dictionary, ctx: Dictionary) -> bool   fires once per scoring event
## on_count(ctx: Dictionary) -> bool                  fires once per count
## on_acquire(run: CribRun)                           fires when bought
## Returning true means "this charm did something" and puts it in ctx.fired.

var id := ""
var name := ""
var tier := 1
var cost := 0
var rarity := "common"
var cat := ""
var text := ""
var rule = null            # Dictionary or null, merged by CribRun.rules()
var on_event := Callable()
var on_count := Callable()
var on_acquire := Callable()


static func make(d: Dictionary) -> Charm:
	var c := Charm.new()
	for k in d:
		c.set(k, d[k])
	return c
