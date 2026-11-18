extends Node
const Kernel = preload("res://Runtime/Scene/RouterKernel.gd")
const Context = preload("res://Runtime/Scene/TransitionContext.gd")
const LayerScene = preload("res://Runtime/Scene/TransitionLayer.tscn")
const Barrier = preload("res://PvE/tests/LoadingBarrier.gd")
const A = "res://PvE/tests/fixtures/router/A.tscn"
const B = "res://PvE/tests/fixtures/router/B.tscn"
const REDIRECT = "res://PvE/tests/fixtures/router/Redirect.tscn"

class FixtureContext extends Context:
	var router: Node
	var acquired = 0
	var released = 0
	func appearance() -> Dictionary: return {"reduce_motion": true, "reduce_flash": true}
	func fade_targets() -> Array:
		return [router.get_current_node()] if is_instance_valid(router) else []
	func acquire_input() -> void:
		acquired += 1
		InputBlocker.activate(InputBlocker.Source.Cinematic, false)
	func release_input() -> void:
		released += 1
		InputBlocker.deactivate(InputBlocker.Source.Cinematic, false)
	func begin_loading(reason: String, current: Callable) -> int:
		return await Expedition.loading_screen.begin_scene(reason, current)
	func finish_loading(ticket: int) -> void: await Expedition.loading_screen.finish(ticket)
	func cancel_loading(ticket: int) -> void: Expedition.loading_screen.cancel(ticket)

var output = ""
var checks: Array = []
var failures: Array = []
var observations: Array = []
var gate = false
var gate_entered = false
var cancelled_prepares = 0
var activation_count = 0
var release_count = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func check(value: bool, label: String):
	checks.append({"ok": value, "label": label})
	if not value: failures.append(label); printerr("ROUTER_CONTRACT_FAIL ", label)

func wait_for(predicate: Callable, seconds = 8.0) -> bool:
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await get_tree().process_frame
	return bool(predicate.call())

func fixture() -> Dictionary:
	var host = Node2D.new(); add_child(host)
	var root = Node2D.new(); host.add_child(root)
	var router = Kernel.new(); host.add_child(router)
	var context = FixtureContext.new(); context.router = router
	var layer = LayerScene.instantiate(); layer.configure(context); host.add_child(layer)
	check(router.configure(AssetStream, layer, root) == OK, "dependencies configure without activation")
	root.set_meta("router_kernel", router)
	var branches: Array = []
	for index in range(3):
		var branch = Node2D.new(); branch.name = "Carrier" + str(index)
		branch.hide(); branch.process_mode = Node.PROCESS_MODE_DISABLED
		host.add_child(branch); branches.append(branch)
	var events: Array = []; var results: Array = []; var phases: Array = []
	router.screen_changed.connect(func(id): events.append(id))
	router.request_finished.connect(func(id, screen, error): results.append({"id": id, "screen": screen, "error": error}))
	router.phase_changed.connect(func(id, phase): phases.append({"id": id, "phase": phase}))
	router.register_screen(&"a", A); router.register_screen(&"b", B)
	router.register_screen(&"redirect", REDIRECT)
	router.register_screen(&"missing", "res://PvE/tests/fixtures/router/intentionally-absent.tscn")
	router.register_screen(&"wrong_type", "res://PvE/tests/fixtures/router/Screen.gd")
	router.register_branch(&"branch_a", branches[0], prepare_gate, activate_branch, release_branch, cancel_branch)
	router.register_branch(&"branch_b", branches[1])
	router.register_branch(&"branch_c", branches[2])
	return {"host": host, "root": root, "router": router, "layer": layer, "context": context,
		"branches": branches, "events": events, "results": results, "phases": phases}

func prepare_gate(options: Dictionary, current: Callable) -> bool:
	gate_entered = true
	while gate and bool(current.call()): await get_tree().process_frame
	return bool(current.call()) and not bool(options.get("reject", false))

func activate_branch(node: Node, _options: Dictionary):
	activation_count += 1; node.process_mode = Node.PROCESS_MODE_INHERIT; node.show()

func release_branch(node: Node):
	release_count += 1; node.hide(); node.process_mode = Node.PROCESS_MODE_DISABLED

func cancel_branch(_options: Dictionary): cancelled_prepares += 1

func settle(value: Dictionary, handle: Dictionary, expected: int, label: String):
	check(handle.error == OK and handle.id > 0, label + ": admitted with stable identity")
	check(await wait_for(func(): return not value.router.result(handle.id).is_empty()), label + ": reaches terminal result")
	check(await value.router.wait_for_request(handle.id) == expected, label + ": expected terminal error")
	check(await wait_for(func(): return not value.router.is_busy()), label + ": worker becomes quiescent")

func route(value: Dictionary, screen: StringName, options: Dictionary = {}) -> Dictionary:
	var handle = value.router.request_scene(screen, options)
	await settle(value, handle, OK, str(screen))
	return handle

func dispose(value: Dictionary):
	value.router.shutdown(); value.layer.shutdown()
	check(await wait_for(func(): return not value.router.is_busy()), "shutdown drains suspended router work")
	check(value.context.acquired == value.context.released, "every visual input acquisition is released exactly once")
	check(not value.layer.busy and Expedition.loading_screen.mode.is_empty(), "fixture leaves no cloud/loading overlay")
	for scope in value.router.diagnostics().resource_slots:
		check(not AssetStream.scopes.has(scope), "shutdown releases bounded route scope " + scope.get_slice(":", 2))
	observations.append({"events": value.events.duplicate(), "results": value.results.duplicate(true), "phases": value.phases.duplicate(true), "diagnostics": value.router.diagnostics()})
	value.host.queue_free(); await get_tree().process_frame

func disabled_and_paths():
	var value = fixture(); var router = value.router
	var stats = AssetStream.metrics.duplicate(true); var generation = value.layer.generation
	check(not ResourceLoader.has_cached(A), "cold path fixture is not preloaded by registration")
	check(router.is_registered(&"a") and router.is_registered(&"branch_a"), "disabled registration supports both backends")
	check(router.change_scene(&"a") == ERR_UNAVAILABLE and router.change_scene(&"unknown") == ERR_UNAVAILABLE, "disabled changes reject before any route lookup/load")
	check(AssetStream.metrics == stats and value.root.get_child_count() == 0, "disabled route performs zero I/O and zero tree mutation")
	check(value.layer.generation == generation and value.events.is_empty() and value.results.is_empty(), "disabled route has zero transition or completion signals")
	check(router.current_screen_id == &"", "disabled registry cannot select an initial screen")
	check(router.set_enabled(true) == OK and router.change_scene(&"unknown") == ERR_DOES_NOT_EXIST, "enabled unknown route rejects synchronously")
	var first = router.request_scene(&"a")
	check(router.request_scene(&"a").id == first.id, "queued identical route coalesces identity")
	check(await wait_for(func(): return value.layer.busy), "actual cloud covers before route preparation")
	check(router.request_scene(&"a").id == first.id, "active identical route coalesces identity")
	await settle(value, first, OK, "cold a")
	var node = router.get_current_node()
	check(node != null and node.marker == "A" and node.created_on_main_thread, "real AssetStream constructs PackedScene on main thread")
	check(node.get_parent() == value.root and node.visible and node.process_mode == Node.PROCESS_MODE_INHERIT, "prepared scene attaches and activates at commit")
	check(router.configure(AssetStream, value.layer, value.root) == ERR_BUSY, "live lease forbids dependency replacement that could leak its old scope")
	check(AssetStream.scopes.has(router.diagnostics().current_scope), "committed route retains its own resource scope")
	check(value.events == [&"a"], "successful reveal emits screen_changed exactly once")
	var idle_stats = AssetStream.metrics.duplicate(true); generation = value.layer.generation
	await settle(value, router.request_scene(&"a"), OK, "already current a")
	check(value.events == [&"a"] and AssetStream.metrics == idle_stats and value.layer.generation == generation, "idle duplicate causes no load, cover or duplicate screen signal")
	check(await router.wait_for_request(999999) == ERR_DOES_NOT_EXIST, "unknown completion identity never hangs")
	var held = node; gate = true; gate_entered = false
	var branch = router.request_scene(&"branch_a", {"first": true})
	check(await wait_for(func(): return gate_entered), "branch preparation reaches real asynchronous gate")
	check(is_instance_valid(held) and router.get_current_node() == held and AssetStream.scopes.has(router.diagnostics().current_scope), "old path and resources stay live while target prepares")
	check(value.root.get_child_count() == 1 and not value.branches[0].visible, "unready branch does not prematurely switch or clone Main")
	gate = false; await settle(value, branch, OK, "branch a")
	await get_tree().process_frame
	check(not is_instance_valid(held) and value.root.get_child_count() == 0, "owned old path retires only after branch commits")
	check(router.get_current_node() == value.branches[0] and value.branches[0].get_parent() == value.host, "branch carrier identity and parent remain intact")
	await route(value, &"branch_b"); await route(value, &"branch_c")
	check(not value.branches[0].visible and not value.branches[1].visible and value.branches[2].visible, "three native-style branch carriers activate exclusively")
	check(activation_count == 1 and release_count == 1, "branch activate/release lifecycle executes once")
	await dispose(value)

func replacements_and_failures():
	var value = fixture(); value.router.set_enabled(true)
	await route(value, &"branch_b")
	var old = value.router.get_current_node(); var cancelled = cancelled_prepares
	gate = true; gate_entered = false
	var pending = value.router.request_scene(&"branch_a", {"abandon": true})
	check(await wait_for(func(): return gate_entered), "replace test enters suspended branch prepare")
	var latest = value.router.request_scene(&"branch_c")
	check(value.router.result(pending.id).error == ERR_SKIP, "replacement immediately finalizes old identity as cancelled")
	check(value.router.get_current_node() == old and old.visible, "logical cancellation retains previous committed carrier")
	await settle(value, latest, OK, "replace waiting branch")
	gate = false
	check(cancelled_prepares == cancelled + 1 and not value.branches[0].visible, "cancelled branch prepare releases once and never activates")
	check(value.events == [&"branch_b", &"branch_c"], "only latest waiting transaction emits success")
	# Use a fresh cold path; observe the real loader's in-flight job before cancellation.
	check(not ResourceLoader.has_cached(B), "second cold fixture has never been loaded")
	var loading = value.router.request_scene(&"b", {"cold": true})
	check(await wait_for(func(): return AssetStream.inflight.has(B)), "actual threaded path load is observed in flight")
	latest = value.router.request_scene(&"branch_b", {"after_io": true})
	await settle(value, latest, OK, "replace in-flight path")
	check(value.router.result(loading.id).error == ERR_SKIP and value.root.get_child_count() == 0, "cancelled I/O cannot attach an obsolete scene")
	check(await wait_for(func(): return not AssetStream.inflight.has(B)), "abandoned thread joins and discards its result")
	check(not AssetStream.resources.has(B), "abandoned resource has no retained route scope")
	# Replacement after construction, before commit.
	var capture = {"candidate": null, "handle": {}, "armed": true}
	var callback = func(_id, phase):
		if phase == &"prepared" and capture.armed:
			capture.armed = false
			capture.candidate = weakref(value.router._active.lease.node)
			capture.handle = value.router.request_scene(&"branch_c", {"after_build": true})
	value.router.phase_changed.connect(callback)
	var built = value.router.request_scene(&"a", {"build": true})
	check(await wait_for(func(): return not capture.handle.is_empty()), "prepared boundary is actually reached before replacement")
	await settle(value, capture.handle, OK, "replace built candidate")
	value.router.phase_changed.disconnect(callback)
	check(capture.candidate.get_ref() == null, "prepared node has no surviving off-tree reference")
	check(value.router.result(built.id).error == ERR_SKIP and capture.candidate.get_ref() == null, "constructed obsolete node is freed without committing")
	# Reentry from a Node's real _ready, inside add_child.
	var redirect = value.router.request_scene(&"redirect")
	check(await wait_for(func(): return value.root.has_meta("redirect_handle")), "candidate _ready actually reenters admission")
	await settle(value, value.root.get_meta("redirect_handle"), OK, "ready redirect")
	check(value.root.get_meta("redirect_was_hidden") and value.root.get_meta("redirect_previous") == &"branch_c", "ready reentry sees hidden candidate and unchanged old commit")
	check(value.router.result(redirect.id).error == ERR_SKIP and value.root.get_child_count() == 0, "ready reentry safely discards candidate after add_child returns")
	# Replacement after commit while the real wipe is revealing.
	var revealing = value.router.request_scene(&"a", {"reveal": true})
	check(await wait_for(func(): return value.layer.revealing), "actual layer reveal begins before replacement")
	var committed = value.router.get_current_node()
	latest = value.router.request_scene(&"branch_c", {"after_reveal": true})
	check(value.router.result(revealing.id).committed and is_instance_valid(committed), "post-commit cancellation preserves actual committed node until next commit")
	await settle(value, latest, OK, "replace revealing transaction")
	check(value.router.result(revealing.id).error == ERR_SKIP and not value.events.has(&"a"), "superseded reveal cannot report success")
	old = value.router.get_current_node(); var events = value.events.size()
	await settle(value, value.router.request_scene(&"missing"), ERR_CANT_OPEN, "missing resource")
	check(value.router.get_current_node() == old and old.visible and is_equal_approx(old.modulate.a, 1.0), "failed preparation restores old visible screen")
	await settle(value, value.router.request_scene(&"wrong_type"), ERR_INVALID_DATA, "non-scene resource")
	await settle(value, value.router.request_scene(&"branch_a", {"reject": true}), ERR_CANT_CREATE, "rejected branch preparation")
	check(value.events.size() == events and value.router.get_current_node() == old, "failure paths emit no successful screen switch and preserve current")
	check(not value.layer.busy and not InputBlocker.isActive(), "failures reveal old screen and release all input ownership")
	await dispose(value)

func bounded_and_reentrant_completion():
	var value = fixture(); value.router.set_enabled(true)
	var sync_before = AssetStream.metrics.sync_misses
	for index in range(6):
		await route(value, &"a" if index % 2 == 0 else &"b", {"iteration": index})
		check(value.root.get_child_count() == 1, "repeated route keeps exactly one committed owned scene")
	var slots: Array = value.router.diagnostics().resource_slots
	var keys = AssetStream.revisions.keys().filter(func(key): return key in slots)
	check(keys.size() == 2, "repeated requests reuse only two revision domain slots")
	check(AssetStream.metrics.sync_misses == sync_before, "route backend never invokes synchronous resource fallback")
	var current = value.router.current_screen_id
	var last_options = value.router._current_options.duplicate(true)
	var event_count = value.events.size(); var gen = value.layer.generation
	for index in range(70):
		var noop = value.router.request_scene(current, last_options)
		check(value.router.result(noop.id).error == OK, "repeated current-screen request completes without deferred work")
	check(value.router._results.size() == Kernel.MAX_RESULTS and value.router._result_order.size() == Kernel.MAX_RESULTS, "completion history is bounded at 64 identities")
	check(value.events.size() == event_count and value.layer.generation == gen, "completion-cache stress does not repeat transitions or success signals")
	var state = {"next": {}, "armed": true}
	var callback = func(id):
		if id == &"branch_b" and state.armed:
			state.armed = false
			state.next = value.router.request_scene(&"branch_c", {"from_signal": true})
	value.router.screen_changed.connect(callback)
	var first = value.router.request_scene(&"branch_b")
	check(await wait_for(func(): return not state.next.is_empty()), "success callback actually admits next request reentrantly")
	await settle(value, state.next, OK, "screen_changed reentry")
	check(value.router.result(first.id).error == OK and first.id != state.next.id, "success is finalized before reentrant next admission")
	check(value.events.count(&"branch_b") == 1 and value.events.count(&"branch_c") == 1, "reentrant completion emits each success once")
	value.router.screen_changed.disconnect(callback)
	var node = value.router.get_current_node(); var events = value.events.size()
	value.router.set_enabled(false)
	var stats = AssetStream.metrics.duplicate(true); var generation = value.layer.generation
	value.router.register_screen(&"after_disable", A)
	check(value.router.change_scene(&"a") == ERR_UNAVAILABLE and value.router.is_registered(&"after_disable"), "disabled-after-use registry stays memory-only")
	check(value.router.get_current_node() == node and AssetStream.metrics == stats and value.events.size() == events and value.layer.generation == generation, "disabling does not alter committed screen or cause new work")
	await dispose(value)

func stop_and_ownership():
	var value = fixture(); value.router.set_enabled(true)
	await route(value, &"a")
	var old = weakref(value.router.get_current_node()); gate = true; gate_entered = false
	var handle = value.router.request_scene(&"branch_a", {"stop": true})
	check(await wait_for(func(): return gate_entered), "shutdown case has a suspended prepare")
	value.router.shutdown(); value.router.shutdown()
	await settle(value, handle, ERR_SKIP, "stopped prepare")
	await get_tree().process_frame
	check(old.get_ref() == null and value.router.current_screen_id == &"", "shutdown retires owned committed node and identity")
	check(value.router.set_enabled(true) == ERR_UNAVAILABLE and value.router.change_scene(&"a") == ERR_UNAVAILABLE, "permanent shutdown rejects restart and new route work")
	check(is_instance_valid(value.branches[0]) and value.branches[0].get_parent() == value.host, "shutdown never destroys caller-owned branch carrier")
	gate = false; await dispose(value)
	value = fixture(); value.router.set_enabled(true)
	var ticket = await value.layer.cover("qa_foreign_owner")
	var generation = value.layer.generation
	check(value.router.change_scene(&"a") == ERR_BUSY, "foreign busy transition is not stolen")
	check(value.layer.generation == generation and value.layer.covered, "rejected route cannot cancel foreign cloud ticket")
	await value.layer.reveal(ticket)
	await dispose(value)

func cover_and_pending_cancellation():
	var value = fixture(); value.router.set_enabled(true)
	var cancels = cancelled_prepares
	var queued = value.router.request_scene(&"branch_a")
	var replaced = value.router.request_scene(&"branch_c")
	await settle(value, replaced, OK, "replace before worker starts")
	check(value.router.result(queued.id).error == ERR_SKIP and cancelled_prepares == cancels, "never-started branch does not run preparation cleanup")
	check(value.events == [&"branch_c"], "queued replacement has only latest success")
	var covering = value.router.request_scene(&"a", {"cover_cancel": true})
	check(await wait_for(func(): return value.layer.busy and not value.layer.covered), "cover cancellation occurs during actual wipe")
	var old = value.router.get_current_node()
	value.router.cancel_current()
	await settle(value, covering, ERR_SKIP, "explicit cover cancellation")
	check(value.router.get_current_node() == old and old.visible and is_equal_approx(old.modulate.a, 1.0), "cancelled cover restores committed screen opacity")
	check(not value.layer.busy and Expedition.loading_screen.mode.is_empty(), "explicit cancellation has terminal visual cleanup")
	check(value.results.filter(func(row): return row.id == covering.id).size() == 1, "cancelled request emits one terminal result")
	await route(value, &"branch_b", {"recovered": true})
	var stopping = value.router.request_scene(&"a", {"cover_stop": true})
	check(await wait_for(func(): return value.layer.busy and not value.layer.covered), "stop case enters actual cloud cover")
	value.router.shutdown()
	await settle(value, stopping, ERR_SKIP, "shutdown while covering")
	check(not value.layer.busy and value.router.get_current_node() == null, "cover shutdown leaves no owned screen or visual lock")
	await dispose(value)

func disable_and_commit_reentry():
	var value = fixture(); value.router.set_enabled(true)
	await route(value, &"branch_b")
	gate = true; gate_entered = false
	var blocked = value.router.request_scene(&"branch_a", {"disable_in_prepare": true})
	check(await wait_for(func(): return gate_entered), "disable case suspends preparation")
	var old = value.router.get_current_node()
	check(value.router.set_enabled(false) == OK, "disable synchronously rejects further admissions")
	await settle(value, blocked, ERR_SKIP, "disable pending preparation")
	check(value.router.get_current_node() == old and old.visible, "disable during prepare retains committed branch")
	var stats = AssetStream.metrics.duplicate(true)
	check(value.router.change_scene(&"a") == ERR_UNAVAILABLE and AssetStream.metrics == stats, "disabled pending worker cannot admit new loads")
	gate = false; value.router.set_enabled(true)
	var state = {"next": {}, "committed": false, "once": true}
	var activate = func(node, _options):
		node.show(); node.process_mode = Node.PROCESS_MODE_INHERIT
		if state.once:
			state.once = false
			state.committed = value.router.get_current_node() == node and value.router.current_screen_id == &"branch_a"
			state.next = value.router.request_scene(&"branch_c", {"activate_redirect": true})
	value.router.register_branch(&"branch_a", value.branches[0], Callable(), activate)
	var committing = value.router.request_scene(&"branch_a")
	check(await wait_for(func(): return not state.next.is_empty()), "activation callback reenters inside commit critical section")
	await settle(value, state.next, OK, "activate reentry")
	check(state.committed and value.router.result(committing.id).committed, "commit identity publishes before activation reentry without domain rollback")
	check(value.router.result(committing.id).error == ERR_SKIP and not value.events.has(&"branch_a"), "cancelled committed transaction cannot emit late success")
	check(value.branches[2].visible and not value.branches[0].visible, "next commit retires previous branch exactly once")
	check(value.context.acquired == value.context.released, "commit reentry does not strand cinematic input ownership")
	await dispose(value)

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	check(await wait_for(func(): return Expedition.initialized, 90.0), "native shell initializes")
	if not Expedition.initialized: await finish(); return
	await Barrier.wait_idle(get_tree())
	while Game.sceneAnimation.is_playing(): await get_tree().process_frame
	Game.titleScreen.itemDropTimer.stop(); Game.titleScreen.itemDropTimer2.stop(); Game.titleScreen.discardAllItems()
	var before = JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true)
	check(SceneRouter.get_script().get_global_name().is_empty() and (Expedition.native_routes == null or SceneRouter.get_current_node() == Expedition.art.routed_title), "production Autoload keeps its name and owns the routed title when enabled")
	await disabled_and_paths()
	await replacements_and_failures()
	await bounded_and_reentrant_completion()
	await stop_and_ownership()
	await cover_and_pending_cancellation()
	await disable_and_commit_reentry()
	await Barrier.wait_idle(get_tree())
	check(not InputBlocker.isActive() and Expedition.loading_screen.mode.is_empty(), "router matrix leaves no loading or input lock")
	check(JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true) == before, "router never mutates authoritative run, domain RNG or flow")
	check(Game.mainNode.get_node("TransitionLayer") == Expedition.art.curtain, "production transition ownership stays unchanged")
	for path in ["res://PvE/tests/RouterContractsMain.tscn", A, B, REDIRECT]:
		var uid = ResourceLoader.get_resource_uid(path)
		check(uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid), "router fixture UID is registered by actual editor import: " + path)
		var resource = ResourceLoader.load(ResourceUID.id_to_text(uid)) if uid != ResourceUID.INVALID_ID else null
		check(resource is PackedScene and resource.resource_path == path, "router fixture resolves through a new-process UID URI: " + path)
	await finish()

func finish():
	var report = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "observations": observations, "physical_mouse_used": false, "production_routing_enabled": Expedition.native_routes != null}
	var file = FileAccess.open(output.path_join("router-contracts-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("ROUTER_CONTRACTS_QA ", checks.size(), " failures=", failures)
	Game._begin_shutdown(); await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)

