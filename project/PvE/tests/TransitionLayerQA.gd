extends Node
const Context = preload("res://Runtime/Scene/TransitionContext.gd")
const LayerScene = preload("res://Runtime/Scene/TransitionLayer.tscn")
const Barrier = preload("res://PvE/tests/LoadingBarrier.gd")

class FixtureContext extends Context:
	var stopping = false
	var delayed = false
	var fail_begin = false
	var options = {"reduce_motion": false, "reduce_flash": false}
	var targets: Array = []
	var acquired = 0
	var released = 0
	var beginnings = 0
	func is_stopping() -> bool: return stopping
	func appearance() -> Dictionary: return options
	func fade_targets() -> Array: return targets
	func acquire_input() -> void:
		acquired += 1
		InputBlocker.activate(InputBlocker.Source.Cinematic, false)
	func release_input() -> void:
		released += 1
		InputBlocker.deactivate(InputBlocker.Source.Cinematic, false)
	func begin_loading(reason: String, current: Callable) -> int:
		while delayed and current.is_valid() and bool(current.call()): await Expedition.get_tree().process_frame
		if fail_begin or not current.is_valid() or not bool(current.call()): return -1
		beginnings += 1
		return await Expedition.loading_screen.begin_scene(reason, current)
	func finish_loading(ticket: int) -> void: await Expedition.loading_screen.finish(ticket)
	func cancel_loading(ticket: int) -> void: Expedition.loading_screen.cancel(ticket)

var output = ""
var checks: Array = []
var failures: Array = []
var observations: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func check(value: bool, label: String):
	checks.append({"ok": value, "label": label})
	if not value: failures.append(label); printerr("TRANSITION_LAYER_FAIL ", label)

func wait_for(predicate: Callable, seconds: float = 5.0) -> bool:
	var deadline = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return bool(predicate.call())

func fixture() -> Dictionary:
	var context = FixtureContext.new()
	var target = Sprite2D.new()
	target.modulate = Color(0.7, 0.8, 0.9, 1.0)
	add_child(target)
	context.targets = [target]
	var layer = LayerScene.instantiate()
	check(layer.configure(context) == OK, "fixture context attaches before activation")
	Game.mainNode.add_child(layer)
	return {"layer": layer, "context": context, "target": target, "original": target.modulate}

func dispose(value: Dictionary):
	value.layer.shutdown()
	value.layer.free()
	value.target.free()

func cover_probe(layer, reason: String, result: Dictionary):
	result.ticket = await layer.cover(reason)
	result.done = true

func reveal_probe(layer, ticket: int, result: Dictionary):
	await layer.reveal(ticket)
	result.done = true

func note(label: String, value: Dictionary):
	observations.append({"case": label, "busy": value.layer.busy, "covered": value.layer.covered, "generation": value.layer.generation,
		"acquired": value.context.acquired, "released": value.context.released, "beginnings": value.context.beginnings, "history": value.layer.history.duplicate(true)})

func normal_and_reduced():
	for reduced in [false, true]:
		var value = fixture()
		value.context.options = {"reduce_motion": reduced, "reduce_flash": reduced}
		var ticket = await value.layer.cover("qa_layer_normal_" + str(reduced))
		check(ticket >= 0 and value.layer.covered, "normal/reduced cover finishes")
		check(is_zero_approx(value.target.modulate.a), "departing target actually fades out")
		check(value.layer.overlay.material.get_shader_parameter("reduced_motion") == reduced, "motion preference reaches real shader")
		check(value.layer.overlay.material.get_shader_parameter("reduced_flash") == reduced, "flash preference reaches real shader")
		check(is_equal_approx(float(value.layer.history.back().duration), 0.13 if reduced else 0.40), "original cover duration preserved")
		InputBlocker.activate(InputBlocker.Source.Popup, false)
		await value.layer.reveal(ticket)
		check(not value.layer.busy and not value.layer.overlay.visible, "normal/reduced reveal releases cloud")
		check(value.target.modulate == value.original, "arriving target retains original tint and fades in")
		check(is_equal_approx(float(value.layer.history.back().duration), 0.16 if reduced else 0.52), "original reveal duration preserved")
		check(value.context.acquired == 1 and value.context.released == 1, "normal reveal releases its lock exactly once")
		check((InputBlocker.curSources & InputBlocker.Source.Popup) != 0, "unrelated input lock survives layer completion")
		InputBlocker.deactivate(InputBlocker.Source.Popup, false)
		note("normal_reduced_" + str(reduced), value)
		dispose(value)

func coalesce_and_reenter():
	var value = fixture()
	var first = {"done": false, "ticket": -1}; var second = {"done": false, "ticket": -1}
	cover_probe(value.layer, "qa_layer_first", first)
	cover_probe(value.layer, "qa_layer_coalesced", second)
	check(await wait_for(func(): return first.done and second.done), "concurrent covers settle without recursion")
	check(first.ticket == second.ticket and first.ticket >= 0, "concurrent covers share the current covered ticket")
	check(value.context.acquired == 1 and value.context.beginnings == 1, "coalescing acquires input and loading only once")
	var leaving = {"done": false}; var next = {"done": false, "ticket": -1}
	reveal_probe(value.layer, first.ticket, leaving)
	cover_probe(value.layer, "qa_layer_after_reveal", next)
	check(await wait_for(func(): return leaving.done and next.done), "cover requested during reveal waits and then completes")
	check(next.ticket > first.ticket and value.layer.covered, "reentry obtains a fresh covered generation")
	check(value.context.acquired == 2 and value.context.released == 1, "previous reveal does not release the new owner lock")
	check(not value.layer.cancel(first.ticket), "stale cancellation cannot cancel a new cover")
	await value.layer.reveal(next.ticket)
	check(value.context.released == 2, "reentered cover releases exactly its own lock")
	note("coalesce_reentry", value); dispose(value)

func cancel_cover_and_delayed_begin():
	var value = fixture(); var pending = {"done": false, "ticket": -1}
	cover_probe(value.layer, "qa_layer_cancel_cover", pending)
	await get_tree().process_frame
	check(value.layer.cancel(value.layer.generation), "active cover can be cancelled synchronously")
	check(await wait_for(func(): return pending.done), "cancelled covering coroutine terminates")
	check(pending.ticket == -1 and value.target.modulate == value.original, "cancel restores tint/alpha and returns no valid ticket")
	check(not value.layer.busy and value.context.released == 1, "cover cancellation clears state and its lock")
	check(Expedition.loading_screen.mode.is_empty(), "cover cancellation hides its loading overlay")
	value.context.delayed = true
	var delayed = {"done": false, "ticket": -1}
	cover_probe(value.layer, "qa_layer_delayed_old", delayed)
	var old_ticket = value.layer.generation
	check(value.layer.cancel(old_ticket), "pending loading begin can be invalidated")
	value.context.delayed = false
	var fresh = await value.layer.cover("qa_layer_delayed_new")
	check(await wait_for(func(): return delayed.done), "invalidated loading begin exits after its awaited boundary")
	check(delayed.ticket == -1 and fresh > old_ticket, "late begin cannot acquire a new valid layer ticket")
	check(value.layer.covered and Expedition.loading_screen.mode == "qa_layer_delayed_new", "late old begin cannot replace or dismiss the new loading UI")
	await value.layer.reveal(fresh)
	note("cancel_cover_delayed_begin", value); dispose(value)

func cancel_reveal_and_loading_finish():
	for during_finish in [false, true]:
		var value = fixture(); var ticket = await value.layer.cover("qa_layer_before_cancel_reveal")
		var leaving = {"done": false}
		reveal_probe(value.layer, ticket, leaving)
		if during_finish:
			check(await wait_for(func(): return Expedition.loading_screen.closing), "real loading completion fade starts before cancellation")
		else: await get_tree().process_frame
		check(value.layer.cancel(ticket), "reveal/loading-finish cancellation succeeds")
		var fresh = await value.layer.cover("qa_layer_new_owner_" + str(during_finish))
		check(await wait_for(func(): return leaving.done), "superseded reveal coroutine terminates")
		check(fresh > ticket and value.layer.covered and value.layer.overlay.visible, "old reveal cannot hide the next cloud cover")
		check(Expedition.loading_screen.root.visible and Expedition.loading_screen.mode == "qa_layer_new_owner_" + str(during_finish), "old loading fade cannot hide or overwrite next loading UI")
		check(value.context.acquired == 2 and value.context.released == 1, "superseded completion cannot clear new input owner")
		await value.layer.reveal(fresh)
		check(value.target.modulate == value.original and value.context.released == 2, "new owner completes with tint and lock restored")
		note("cancel_reveal_" + str(during_finish), value); dispose(value)

func stop_and_leave_tree():
	var value = fixture(); var first = {"done": false, "ticket": -1}; var second = {"done": false, "ticket": -1}
	cover_probe(value.layer, "qa_layer_stop_first", first); cover_probe(value.layer, "qa_layer_stop_waiter", second)
	value.context.stopping = true
	check(await wait_for(func(): return first.done and second.done), "stop terminates covering and coalescing waiters without recursion")
	check(first.ticket == -1 and second.ticket == -1 and not value.layer.busy, "stopped layer returns no success tickets")
	check(value.context.released == 1 and value.target.modulate == value.original, "stop releases exactly one owned lock and restores target")
	value.layer.shutdown(); value.layer.shutdown()
	check(value.context.released == 1 and await value.layer.cover("qa_layer_after_stop") == -1, "shutdown is idempotent and permanently refuses new covers")
	note("stop", value); dispose(value)
	value = fixture(); var removed = {"done": false, "ticket": -1}
	cover_probe(value.layer, "qa_layer_remove", removed)
	Game.mainNode.remove_child(value.layer)
	check(await wait_for(func(): return removed.done), "leaving the tree terminates suspended cover")
	check(removed.ticket == -1 and value.context.released == 1 and value.target.modulate == value.original, "tree exit cancels and restores without stale completion")
	dispose(value)

func failure_and_resource_isolation():
	var value = fixture(); value.context.fail_begin = true
	check(await value.layer.cover("qa_layer_loading_failure") == -1, "loading begin failure is reported as no valid ticket")
	check(not value.layer.busy and value.context.acquired == value.context.released, "begin failure leaves no cloud/input ownership")
	dispose(value)
	var first = fixture(); var second = fixture()
	check(first.layer.overlay.material != second.layer.overlay.material, "editable scene creates isolated shader materials")
	first.layer.overlay.material.set_shader_parameter("coverage", 0.75)
	check(is_zero_approx(float(second.layer.overlay.material.get_shader_parameter("coverage"))), "one layer instance cannot change another shader's coverage")
	dispose(first); dispose(second)
	var denied = await Expedition.loading_screen.begin_scene("qa_layer_denied", func(): return false)
	check(denied == -1 and Expedition.loading_screen.mode.is_empty(), "real loader rejects invalid ownership before starting a new overlay")

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	check(await wait_for(func(): return Expedition.initialized, 90.0), "native shell initializes")
	if not Expedition.initialized: await finish(); return
	await Barrier.wait_idle(get_tree())
	while Game.sceneAnimation.is_playing(): await get_tree().process_frame
	Game.titleScreen.itemDropTimer.stop(); Game.titleScreen.itemDropTimer2.stop(); Game.titleScreen.discardAllItems()
	var before = JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true)
	check(Game.mainNode.get_node_or_null("TransitionLayer") == Expedition.art.curtain, "compatibility reference points to the one persistent Main layer")
	check(Expedition.art.curtain.get_parent() == Game.mainNode, "transition layer lifetime belongs to shell rather than art rebuilds")
	check(Expedition.loading_screen.layer > Expedition.art.curtain.layer, "shared progress remains above clouds")
	check(Expedition.native_routes == null or SceneRouter.get_current_node() == Expedition.art.routed_title, "enabled production router owns the title scene")
	for path in ["res://Runtime/Scene/TransitionLayer.tscn", "res://PvE/tests/TransitionLayerMain.tscn"]:
		var uid = ResourceLoader.get_resource_uid(path)
		check(uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid), "new scene UID is registered automatically: " + path)
		var resource = ResourceLoader.load(ResourceUID.id_to_text(uid)) if uid != ResourceUID.INVALID_ID else null
		check(resource is PackedScene and resource.resource_path == path, "new scene resolves through its real UID URI: " + path)
	await normal_and_reduced()
	await coalesce_and_reenter()
	await cancel_cover_and_delayed_begin()
	await cancel_reveal_and_loading_finish()
	await stop_and_leave_tree()
	await failure_and_resource_isolation()
	await Barrier.wait_idle(get_tree())
	var remaining = Game.mainNode.get_children().filter(func(node): return node.get_script() == preload("res://Runtime/Scene/TransitionLayer.gd"))
	check(remaining.size() == 1 and remaining[0] == Expedition.art.curtain, "fixtures leave exactly the persistent production layer")
	check(not InputBlocker.isActive() and Expedition.loading_screen.mode.is_empty(), "layer matrix leaves no stuck input or loading overlay")
	check(JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true) == before, "all transition cases preserve authoritative domain state")
	await finish()

func finish():
	var report = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "observations": observations, "physical_mouse_used": false}
	var file = FileAccess.open(output.path_join("transition-layer-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("TRANSITION_LAYER_QA ", checks.size(), " failures=", failures)
	Game._begin_shutdown(); await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
