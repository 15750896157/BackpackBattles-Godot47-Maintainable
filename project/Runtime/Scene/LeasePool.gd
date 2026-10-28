extends Node
## Scene cache with checkout generations, protecting delayed returns after reuse.

var instances: Dictionary = {}
var _disposing = false
const MAX_PER_SCENE = 2
const MAX_CACHED = 24
const IDLE_SECONDS = 8.0
var _last_trim: float = 0

func cached_count() -> int:
	var count = 0
	for values in instances.values(): count += values.size()
	return count

func _process(_delta):
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_trim < 1.0: return
	_last_trim = now
	for scene in instances.keys():
		var keep = []
		for node in instances[scene]:
			if is_instance_valid(node):
				if now - float(node.get_meta("pool_idle", now)) > IDLE_SECONDS: node.free()
				else: keep.append(node)
		if keep.is_empty(): instances.erase(scene)
		else: instances[scene] = keep


func _create(scene: PackedScene):
	var node = scene.instantiate()
	node.preset()
	if "poolingHandle" in node:
		node.poolingHandle = scene
	return node

func insertInstance(node, scene: PackedScene):
	if _disposing:
		if is_instance_valid(node):
			node.free()
		return
	if instances.get(scene, []).size() >= MAX_PER_SCENE or cached_count() >= MAX_CACHED:
		# Animation-finished signals can return their own emitter. Free it once
		# the callback unwinds, rather than deleting a locked object mid-signal.
		node.queue_free()
		return
	if not instances.has(scene): instances[scene] = []
	node.set_meta("pool_idle", Time.get_ticks_msec() / 1000.0)
	instances[scene].append(node)

func prepare(scene: PackedScene, number: int):
	if not instances.has(scene):
		instances[scene] = []
	for index in mini(number, mini(MAX_PER_SCENE - instances[scene].size(), MAX_CACHED - cached_count())):
		insertInstance(_create(scene), scene)
	if instances[scene].is_empty(): instances.erase(scene)

func instantiate(scene: PackedScene):
	var cached = instances.get(scene)
	var node
	if cached != null:
		node = cached.pop_back()
		if cached.is_empty():
			instances.erase(scene)
		node.request_ready()
	else:
		node = _create(scene)
	node.set_meta("pool_lease", int(node.get_meta("pool_lease", 0)) + 1)
	return node

func returnInstance(node: Node, scene: PackedScene = null):
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if _disposing:
		node.free()
		return
	var handle = scene if scene != null else node.poolingHandle
	var parent = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if node not in instances.get(handle, []):
		insertInstance(node, handle)

func returnAfter(delay: float, node: Node, scene: PackedScene = null):
	if is_instance_valid(node):
		var identity = node.get_instance_id()
		var generation = int(node.get_meta("pool_lease", 0))
		Util.callDelayed_process(self, "returnInstanceById", delay, [identity, generation, scene])

func returnInstanceById(identity: int, generation: int, scene: PackedScene = null):
	var node = instance_from_id(identity)
	if node is Node and is_instance_valid(node) and int(node.get_meta("pool_lease", 0)) == generation:
		returnInstance(node, scene)

func clear():
	_disposing = true
	for cache in instances.values():
		for node in cache:
			if is_instance_valid(node):
				node.free()
	instances.clear()
	_disposing = false

func _exit_tree():
	clear()
	_disposing = true

func particleOneShot(scene, parent, global_position = null):
	var particles = instantiate(scene)
	parent.add_child(particles)
	particles.restart()
	var duration = particles.lifetime * (2.0 - particles.explosiveness) / particles.speed_scale
	returnAfter(duration, particles)
	if global_position != null:
		particles.global_position = global_position
	return particles

func playAnimation(scene, animation_name, parent, below_node = null):
	var node = instantiate(scene)
	if below_node != null:
		below_node.add_sibling(node)
	else:
		parent.add_child(node)
	node.get_node("AnimationPlayer").play(animation_name)
	return node
