extends Node
## Background IO, bounded main-thread construction, and explicit resource scopes.
## Nodes and the active SceneTree are always accessed on the main thread.
const MAX_IO = 1
const INSTANCE_BUDGET_US = 2500
const MAX_INSTANCES_PER_FRAME = 1
var resources: Dictionary = {}
var scopes: Dictionary = {}
var revisions: Dictionary = {}
var pending: Array[String] = []
var inflight: Dictionary = {}
var failed: Dictionary = {}
var jobs: Array = []
var stopping: bool = false
var metrics = {"requested": 0, "loaded": 0, "released": 0, "cancelled": 0, "instances": 0, "sync_misses": 0, "job_max_us": 0, "budget_overruns": 0, "max_inflight": 0}
var job_costs: Dictionary = {}
var effect_paths: Dictionary = {}
var sync_paths: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	effect_paths = JSON.parse_string(FileAccess.get_file_as_string("res://Runtime/Loading/item_effects.json"))

func prepare_effects(kind: String) -> bool:
	return await prepare(effect_paths[kind], "fx-" + kind)

func hold(paths: Array, scope: String) -> int:
	if stopping: return -1
	var keep = {}
	for value in paths:
		var path = str(value)
		if path.is_empty(): continue
		keep[path] = true
		if not resources.has(path) and not pending.has(path) and not inflight.has(path):
			failed.erase(path)
			pending.append(path)
			metrics.requested += 1
	scopes[scope] = keep
	revisions[scope] = int(revisions.get(scope, 0)) + 1
	_trim()
	return revisions[scope]

func current(scope: String, revision: int) -> bool:
	return scopes.has(scope) and int(revisions.get(scope, -1)) == revision

func prepare(paths: Array, scope: String) -> bool:
	var revision = hold(paths, scope)
	while current(scope, revision):
		var waiting = false
		for path in scopes[scope]:
			if failed.has(path): return false
			if not resources.has(path): waiting = true
		if not waiting: return true
		await get_tree().process_frame
	metrics.cancelled += 1
	return false

func request_resource(path: String, scope: String):
	if stopping: return null
	# Append an independently requested thumbnail without invalidating its peers.
	if not scopes.has(scope): hold([], scope)
	var revision = int(revisions[scope])
	scopes[scope][path] = true
	if not resources.has(path) and not inflight.has(path) and not pending.has(path):
		failed.erase(path)
		pending.append(path)
		metrics.requested += 1
	while current(scope, revision):
		if resources.has(path): return resources[path]
		if failed.has(path): return null
		await get_tree().process_frame
	return null

func prepare_actor(character_class: int, chibi: bool, scope: String, include_skins: bool) -> bool:
	if Expedition.enabled:
		var supplied: Array = ["res://PvE/Art/Portrait.tscn"]
		var catalog = preload("res://PvE/Art/SuppliedArt.gd")
		var key = preload("res://PvE/Art/Portrait.gd").enemy_art() if scope == "actor-enemy" else catalog.player_key(character_class)
		supplied.append(catalog.actor_path(key))
		if scope != "actor-enemy": supplied.append(catalog.shop_actor_path(key))
		return await prepare(supplied, scope)
	var actor: CharacterClass = Game.classResources[character_class]
	var paths: Array = [actor.chibi_path if chibi else actor.sprite_path]
	if include_skins:
		for slot in Game.SkinSlot.size():
			var key = Game.getSkinConfigKey(slot, character_class, chibi)
			var id = int(Game.getConfigValue("Wardrobe", key, 0))
			var skin = SkinBook.getSkinFromId(character_class, int(chibi), id)
			var unlocked = Game.persistent.get("unlockedSkins", {}).get(Game.getSkinUnlockKey(slot, character_class, chibi), [])
			if skin.prices[slot] != 0 and id not in unlocked: skin = SkinBook.getSkinFromId(character_class, int(chibi), 0)
			if skin.scene_path not in paths: paths.append(skin.scene_path)
	return await prepare(paths, scope)

func resolve(path: String):
	if path.is_empty(): return null
	if resources.has(path): return resources[path]
	# Legacy callers retain a synchronous compatibility path. Normal local views
	# preload their scope first; this counter exposes accidental blocking loads.
	metrics.sync_misses += 1
	sync_paths[path] = int(sync_paths.get(path, 0)) + 1
	return ResourceLoader.load(path)

func instantiate_path(path: String, scope: String):
	var revision = int(revisions.get(scope, -1))
	if not current(scope, revision) or not resources.has(path): return null
	var job = {"path": path, "scope": scope, "revision": revision, "done": false, "node": null}
	jobs.append(job)
	while not job.done: await get_tree().process_frame
	var node = job.node
	job.node = null
	if not current(scope, revision):
		if is_instance_valid(node): node.free()
		return null
	return node

func release(scope: String):
	scopes.erase(scope)
	revisions[scope] = int(revisions.get(scope, 0)) + 1
	_trim()

func _held(path: String) -> bool:
	for keep in scopes.values():
		if keep.has(path): return true
	return false

func _trim():
	for path in failed.keys():
		if not _held(path): failed.erase(path)
	for path in resources.keys():
		if not _held(path):
			resources.erase(path)
			metrics.released += 1
	for path in pending.duplicate():
		if not _held(path): pending.erase(path)

func release_metadata():
	# Active item/actor nodes own their actual textures independently. Lazy
	# descriptors must not keep scenes alive after their view has been destroyed.
	for descriptor in ItemBook.items.values(): descriptor.release_resources()
	for styles in SkinBook.skins:
		for skins in styles:
			for skin in skins: skin.release_resources()
	for resource in Game.classResources:
		if resource != null: resource.release_resources()

func stats() -> Dictionary:
	var result = metrics.duplicate()
	result.merge({"resident": resources.size(), "scopes": scopes.size(), "pending": pending.size(), "inflight": inflight.size(), "jobs": jobs.size(), "failures": failed.keys()})
	result["job_costs"] = job_costs.duplicate(true)
	result["sync_paths"] = sync_paths.duplicate()
	return result

func stop_requests():
	stopping = true
	for scope in scopes.keys(): release(scope)
	for job in jobs:
		if is_instance_valid(job.node): job.node.queue_free()
		job.node = null
		job.done = true
	jobs.clear()
	release_metadata()

func drain() -> bool:
	stop_requests()
	var deadline = Time.get_ticks_msec() + 5000
	while not inflight.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return inflight.is_empty()

func _process(_delta):
	# The worker owns only a ResourceLoader call and returns its resource.
	# Explicitly joining completed threads avoids retaining threaded-load tokens
	# on this pinned 4.7 runtime. Never construct Nodes on the worker.
	for path in inflight.keys():
		var request = inflight[path]
		if request.is_alive(): continue
		var resource = request.wait_to_finish()
		inflight.erase(path)
		if resource != null:
			metrics.loaded += 1
			if _held(path): resources[path] = resource
			else: metrics.released += 1
		else: failed[path] = ERR_CANT_OPEN
	while inflight.size() < MAX_IO and not pending.is_empty():
		var path = pending.pop_front()
		if not _held(path): continue
		if not ResourceLoader.exists(path):
			failed[path] = ERR_FILE_NOT_FOUND
			continue
		var request = Thread.new()
		var error = request.start(_read_job.bind(path), Thread.PRIORITY_LOW)
		if error == OK: inflight[path] = request
		else: failed[path] = error
		metrics.max_inflight = maxi(metrics.max_inflight, inflight.size())
	var began = Time.get_ticks_usec()
	var count = 0
	while not jobs.is_empty() and count < MAX_INSTANCES_PER_FRAME and Time.get_ticks_usec() - began < INSTANCE_BUDGET_US:
		var job = jobs.pop_front()
		if current(job.scope, job.revision) and resources.get(job.path) is PackedScene:
			var start = Time.get_ticks_usec()
			job.node = resources[job.path].instantiate()
			var elapsed = Time.get_ticks_usec() - start
			metrics.instances += 1
			var costs = job_costs.get(job.path, {"count": 0, "max_us": 0, "total_us": 0})
			costs.count += 1
			costs.max_us = maxi(costs.max_us, elapsed)
			costs.total_us += elapsed
			job_costs[job.path] = costs
			metrics.job_max_us = maxi(metrics.job_max_us, elapsed)
			if elapsed > INSTANCE_BUDGET_US: metrics.budget_overruns += 1
			count += 1
		else: metrics.cancelled += 1
		job.done = true

func _read_job(path: String):
	return ResourceLoader.load(path)

func _exit_tree():
	for request in inflight.values():
		request.wait_to_finish()
	inflight.clear()
