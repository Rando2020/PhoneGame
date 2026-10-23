extends SceneTree
## Renders the free end card (needs xvfb-run): /tmp/free_end_<W>x<H>_<scale>.png
## at 720x1560 and 720x1280, Standard and Larger text, with a stand-in store
## price, and with the simulated iPhone safe area.
class FakeStore extends Object:
	signal purchased(id: String)
	signal restored(ids: Array)
	signal failed(id: String, reason: String)
	func products() -> Array:
		return [{"id": Entitlement.FULL_ID, "price": "$2.99"}]
	func purchase(_id: String) -> void:
		failed.emit(_id, "cancelled")
	func restore() -> void:
		restored.emit([])


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "drag_hint": 1})
	Entitlement.force = false
	var fs := FakeStore.new()
	Engine.register_singleton("MeldStore", fs)
	SafeArea.simulate = {"top": 109.0, "bottom": 63.0}
	for view in [Vector2i(720, 1560), Vector2i(720, 1280)]:
		for sc in [1.0, 1.3]:
			root.size = view
			TypeScale.scale = sc
			var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
			root.add_child(f)
			TypeScale.scale = sc
			TypeScale.relayout(root)
			for i in 3: await process_frame
			var run := CribRun.new("thump", null, null, 77)
			run.round = CribData.ROUNDS
			f.run = run
			f.show_free_end()
			for i in 20: await process_frame
			f.settle()
			if sc > 1.0:
				f.buttons["unlock"].emit_signal("pressed")    # shows the cancelled line
			for i in 10: await process_frame
			root.get_texture().get_image().save_png("/tmp/free_end_%dx%d_%.1f.png" % [view.x, view.y, sc])
			f.queue_free()
			await process_frame
	Engine.unregister_singleton("MeldStore")
	quit()
