extends Node

var output: String = ""
var checks: int = 0
var failures: Array = []
var cycles: Array = []
var reveal_observations: Array = []
const Barrier = preload("res://PvE/tests/LoadingBarrier.gd")

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func check(condition, message: String):
	checks += 1
	if not condition: failures.append(message); print("LOADING_FAILURE ", message)

func settle():
	await Barrier.wait_idle(get_tree())
	for index in 6: await get_tree().process_frame

func load_probe(paths: Array, scope: String, result: Dictionary):
	result.ok = await AssetStream.prepare(paths, scope)
	result.done = true

func instance_probe(path: String, scope: String, result: Dictionary):
	result.node = await AssetStream.instantiate_path(path, scope)
	result.frame = Engine.get_process_frames()
	result.done = true

func quiet_title():
	Game.sceneAnimation.advance(100)
	Game.titleScreen.itemDropTimer.stop()
	Game.titleScreen.itemDropTimer2.stop()
	Game.titleScreen.discardAllItems()
	AssetStream.release("title-decoration")
	ObjectPool.clear()
	AssetStream.release_metadata()
	Expedition.scenery.trim_inactive()
	await settle()

func sample(label: String) -> Dictionary:
	return {"label": label, "static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "nodes": get_tree().get_node_count(), "stream": AssetStream.stats()}

func reveal_probe(kind: String, ticket: int, epoch: int, result: Dictionary):
	await Expedition.art.reveal_ready(kind, ticket, epoch)
	result.done = true

func wait_reveal_probe(result: Dictionary) -> bool:
	var deadline = Time.get_ticks_msec() + 5000
	while not result.done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return result.done

func check_cover_retained(label: String, ticket: int):
	var curtain = Expedition.art.curtain
	var covered = curtain.busy and curtain.covered and not curtain.revealing and curtain.generation == ticket
	var locked = (InputBlocker.curSources & InputBlocker.Source.Cinematic) != 0
	var loading = Expedition.loading_screen.root.visible and not Expedition.loading_screen.mode.is_empty()
	check(covered, label + ": stale caller leaves current cover intact")
	check(locked, label + ": stale caller cannot clear cinematic lock")
	check(loading, label + ": stale caller cannot finish current loading overlay")
	reveal_observations.append({"case": label, "covered": covered, "locked": locked, "loading": loading, "ticket": ticket, "view_epoch": Expedition.view_epoch})

func reveal_contracts():
	var before = JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true)
	for scenario in [{"name": "expired_on_entry", "kind": "combat", "epoch_delta": -1, "ticket_delta": 0},
		{"name": "wrong_cloud_ticket", "kind": "title", "epoch_delta": 0, "ticket_delta": 1}]:
		var ticket = await Expedition.art.curtain.cover("qa_reveal_" + scenario.name)
		await Expedition.art.reveal_ready(scenario.kind, ticket + int(scenario.ticket_delta), Expedition.view_epoch + int(scenario.epoch_delta))
		check_cover_retained(scenario.name, ticket)
		await Expedition.art.curtain.reveal(ticket)
		await settle()
	for kind in ["combat", "title"]:
		var label = "expired_while_waiting" if kind == "combat" else "expired_during_final_frame"
		var ticket = await Expedition.art.curtain.cover("qa_reveal_" + label)
		var result = {"done": false}
		reveal_probe(kind, ticket, Expedition.view_epoch, result)
		# Combat is deliberately not ready on Title; Title reaches the final yield.
		if kind == "combat": await get_tree().process_frame
		check(not result.done, label + ": probe reached a real asynchronous wait")
		Expedition.view_epoch += 1
		check(await wait_reveal_probe(result), label + ": cancelled waiter exits within deadline")
		check_cover_retained(label, ticket)
		await Expedition.art.curtain.reveal(ticket)
		await settle()
	var readiness_ticket = await Expedition.art.curtain.cover("qa_reveal_readiness_changed")
	var readiness_result = {"done": false}
	reveal_probe("title", readiness_ticket, Expedition.view_epoch, readiness_result)
	var previous_ready_kind = Expedition.art.ready_kind
	Expedition.art.ready_kind = ""
	await get_tree().process_frame
	await get_tree().process_frame
	var held_for_ready = Expedition.art.curtain.covered and not Expedition.art.curtain.revealing and not readiness_result.done
	check(held_for_ready, "final reveal frame rechecks target construction readiness")
	Expedition.art.ready_kind = previous_ready_kind
	check(await wait_reveal_probe(readiness_result), "current caller resumes when the target is ready again")
	await settle()
	check(not Expedition.art.curtain.busy and (InputBlocker.curSources & InputBlocker.Source.Cinematic) == 0, "resumed reveal completes and releases its cinematic lock")
	check(Expedition.loading_screen.mode.is_empty(), "resumed reveal finishes the shared loading overlay")
	reveal_observations.append({"case": "readiness_lost_in_final_frame", "held_until_ready": held_for_ready, "completed_after_ready": readiness_result.done})
	var valid_ticket = await Expedition.art.curtain.cover("qa_reveal_valid_owner")
	InputBlocker.activate(InputBlocker.Source.Popup, false)
	await Expedition.art.reveal_ready("title", valid_ticket, Expedition.view_epoch)
	await settle()
	check(not Expedition.art.curtain.busy, "current view owner still completes normal reveal")
	check((InputBlocker.curSources & InputBlocker.Source.Cinematic) == 0, "current view owner releases cinematic lock")
	check((InputBlocker.curSources & InputBlocker.Source.Popup) != 0, "reveal preserves unrelated input lock ownership")
	check(Expedition.loading_screen.mode.is_empty() and not Expedition.loading_screen.root.visible, "current view owner finishes loading overlay")
	InputBlocker.deactivate(InputBlocker.Source.Popup, false)
	check(JSON.stringify({"run": Expedition.flow.run, "flow": Expedition.flow.screen_state, "native": Game.state}, "", true, true) == before, "reveal cancellation never changes domain run or native state")

func run_tests():
	while not Expedition.initialized: await get_tree().process_frame
	await settle()
	await Expedition.return_to_title()
	await quiet_title()
	check(ItemBook.prepareQueue.is_empty() and ItemBook.preparedItemInstances.is_empty(), "no global item preconstruction")
	check(Game.itemLibrary.items.is_empty(), "catalog starts without hundreds of item nodes")
	check(Game.shopSceneNode.get_node("Background").texture == null, "title does not retain shop background texture")
	check(Game.combatSceneNode.backgroundNode.get_child_count() == 0, "title does not retain combat background scene")
	check(not is_instance_valid(Game.wardrobe), "wardrobe not constructed at startup")
	await reveal_contracts()

	var path = "res://Art/Items/LeatherBag.tscn"
	check(not AssetStream.resources.has(path), "cancellation fixture starts after title transition and decoration cleanup")
	var cancelled = {"done": false}
	load_probe([path], "qa-cancel", cancelled)
	await get_tree().process_frame
	AssetStream.release("qa-cancel")
	await settle()
	check(cancelled.done and not cancelled.ok, "abandoned IO is logically cancelled and drained")
	check(not AssetStream.resources.has(path), "cancelled scope retains no resource")

	check(await AssetStream.prepare([path], "qa-instances"), "real recovered scene loaded in background")
	var results: Array = []
	for index in 6:
		var result = {"done": false}
		results.append(result)
		instance_probe(path, "qa-instances", result)
	await settle()
	var creation_frames = {}
	for result in results:
		check(result.done and is_instance_valid(result.get("node")), "scheduled original instance completes")
		creation_frames[result.frame] = true
		if is_instance_valid(result.get("node")): result.node.free(); result.node = null
	check(creation_frames.size() == 6, "six constructions occur on six separate main frames")
	var stale = {"done": false}
	instance_probe(path, "qa-instances", stale)
	AssetStream.release("qa-instances")
	await settle()
	check(stale.done and stale.node == null, "cancelled construction cannot create a stale detached node")

	DirAccess.make_dir_recursive_absolute(output)
	var retry_path = output.path_join("retry-resource-"+str(OS.get_process_id())+".tres")
	check(not await AssetStream.prepare([retry_path], "qa-retry"), "missing resource reports failure without blocking the UI")
	var gradient = Gradient.new()
	check(ResourceSaver.save(gradient, retry_path) == OK, "retry fixture created in isolated test output")
	check(await AssetStream.prepare([retry_path], "qa-retry"), "failed resource can be retried after it becomes available")
	AssetStream.release("qa-retry")
	gradient = null
	await settle()

	for cycle in 8:
		check(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 92141 + cycle, true).ok, "cycle starts authoritative saved run")
		await settle()
		check(Expedition.flow.choose_route(0).ok, "cycle enters first shop")
		await settle()
		Game.sceneAnimation.advance(100)
		check(Expedition.scenery.live.has("shop"), "shop background exists only while needed")
		check(Game.PLAYER.INVENTORY.getItems().size() == Expedition.flow.run.build.bags.size() + Expedition.flow.run.build.items.size(), "asynchronous player view matches saved build")
		var fingerprint = JSON.parse_string(JSON.stringify(Expedition.flow.run.build))
		Expedition.show_codex()
		await settle()
		check(AssetStream.scopes.get("popup", {}).size() > 0, "codex streams image resources without full item scenes")
		Expedition.close_popup()
		await settle()
		check(Expedition.popup_content.get_child_count() == 0 and not AssetStream.scopes.has("popup"), "closing codex frees controls and resource scope")
		await Expedition.return_to_title()
		await quiet_title()
		check(Game.PLAYER.INVENTORY.getItems().is_empty() and Game.STORAGEBOX.getItems().is_empty(), "returning to title destroys player and storage views")
		check(not AssetStream.scopes.has("shop") and not AssetStream.scopes.has("build-player"), "title releases run resource scopes")
		check(Game.combatSceneNode.backgroundNode.get_child_count() == 0 and not Expedition.scenery.live.has("shop"), "unneeded shop and combat scenery are unloaded")
		check(Expedition.flow.continue_run().ok, "saved run continues after all its views were destroyed")
		await settle()
		if cycle == 0:
			var comparison = FileAccess.open(output.path_join("restore-build-comparison.json"), FileAccess.WRITE)
			comparison.store_string(JSON.stringify({"before": fingerprint, "after": Expedition.flow.run.build}, "\t"));comparison.close()
		check(Expedition.flow.run.build == fingerprint, "unloading never changes authoritative inventory or save")
		await Expedition.return_to_title()
		await quiet_title()
		cycles.append(sample("cycle_%d" % cycle))
		check(ObjectPool.cached_count() <= ObjectPool.MAX_CACHED, "shared effects pool remains bounded")
		check(AssetStream.inflight.is_empty() and AssetStream.jobs.is_empty(), "cycle leaves no pending jobs")

	var first: Dictionary = cycles[1]
	var last: Dictionary = cycles.back()
	check(float(last.static_bytes) - float(first.static_bytes) < 12 * 1024 * 1024, "warmed repeated visits do not accumulate large resource caches")
	check(float(last.orphans) - float(first.orphans) <= 8, "repeated visits do not accumulate detached scene nodes")
	check(int(AssetStream.metrics.max_inflight) <= AssetStream.MAX_IO, "background IO concurrency is bounded")
	check(AssetStream.failed.is_empty(), "all active resource scopes are healthy after failure retry")
	var report = {"checks": checks, "failures": failures, "cycles": cycles, "reveal_observations": reveal_observations, "stream": AssetStream.stats(), "limits": {"io": AssetStream.MAX_IO, "instances_per_frame": AssetStream.MAX_INSTANCES_PER_FRAME, "budget_us": AssetStream.INSTANCE_BUDGET_US, "pool": ObjectPool.MAX_CACHED}}
	var file = FileAccess.open(output.path_join("loading-contracts-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"));file.close()
	print("LOADING_CONTRACTS ", JSON.stringify(report))
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
