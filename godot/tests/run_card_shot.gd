extends SceneTree
## Renders a run card (needs xvfb-run): /tmp/run_card.png, the real 1080x1350.
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	Achv.persist = false
	var run := CribRun.new("thump", Meta.STREETS[1], null, 7011)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		run.charms.append(CribData.charm_by_id(id))
	run.act = 4
	run.round = 2
	run.best_count = 412
	var c := RunCard.build(run, false, "2026-10-22")
	root.add_child(c)
	c.render_to("/tmp/run_card.png", func(p):
		print("run card: ", p)
		quit())
