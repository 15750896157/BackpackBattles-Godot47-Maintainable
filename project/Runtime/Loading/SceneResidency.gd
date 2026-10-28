extends RefCounted
## Original backgrounds are streamed separately. Main retains their animation
## anchors, so recovered scene transitions keep their original target paths.
const PATHS = {"shop": "res://Runtime/Loading/Scenes/ShopBackdrop.tscn", "combat": "res://Runtime/Loading/Scenes/CombatBackdrop.tscn"}
var live: Dictionary = {}
var loading: Dictionary = {}

func ensure_view(kind: String) -> bool:
	if live.has(kind): return true
	while loading.get(kind, false):
		await AssetStream.get_tree().process_frame
		if live.has(kind): return true
	loading[kind] = true
	var selected_path = PATHS[kind]
	if kind == "combat":
		var act = clampi(int(Expedition.flow.run.get("act",1)),1,3)
		selected_path = ["res://Runtime/Loading/Scenes/CombatBackdrop1.tscn","res://Runtime/Loading/Scenes/CombatBackdrop2.tscn","res://Runtime/Loading/Scenes/CombatBackdrop3.tscn"][act-1]
	var scope = "decor-" + kind
	if not await AssetStream.prepare([selected_path], scope):
		loading.erase(kind)
		return false
	var payload = await AssetStream.instantiate_path(selected_path, scope)
	loading.erase(kind)
	if payload == null: return false
	var anchor = Game.shopSceneNode.get_node("Background") if kind == "shop" else Game.combatSceneNode.backgroundNode
	if payload is Sprite2D: anchor.texture = payload.texture
	var children = payload.get_children()
	for child in children:
		_clear_owner(child)
		payload.remove_child(child)
		anchor.add_child(child)
	payload.free()
	live[kind] = children
	if kind == "combat":
		Game.combatSceneNode.backgroundAnimation = anchor.get_node("BackgroundAnimation")
		Game.combatSceneNode.clippedNodes.clear()
		for child in children:
			if child.is_in_group("Clipped"): Game.combatSceneNode.clippedNodes.append(child)
	return true

func _clear_owner(node: Node):
	node.owner = null
	for child in node.get_children(): _clear_owner(child)

func unload(kind: String):
	AssetStream.release("decor-" + kind)
	if not live.has(kind): return
	if kind == "combat":
		Game.combatSceneNode.backgroundAnimation = null
		Game.combatSceneNode.clippedNodes.clear()
	else:
		Game.shopSceneNode.get_node("Background").texture = null
		for slot in Game.shopSceneNode.slots: slot.pve_reset()
		AssetStream.release("shop")
		AssetStream.release("fx-shop")
	for child in live[kind]:
		if is_instance_valid(child):
			if child.get_parent() != null: child.get_parent().remove_child(child)
			child.queue_free()
	live.erase(kind)

func trim_inactive():
	var transition = Game.sceneAnimation.is_playing()
	for root in [Game.shopSceneNode, Game.combatSceneNode, Game.titleScreen]:
		var active = transition or (root == Game.shopSceneNode and Game.state == Game.State.Shop) or (root == Game.combatSceneNode and Game.state == Game.State.Combat) or (root == Game.titleScreen and Game.state == Game.State.Title)
		var disabled = root.process_mode == Node.PROCESS_MODE_DISABLED
		if disabled == not active: continue
		root.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		for particles in root.find_children("*", "GPUParticles2D", true, false):
			if particles.one_shot: continue
			if not active and particles.emitting:
				particles.set_meta("stream_resume_emission", true)
				particles.emitting = false
			elif active and particles.has_meta("stream_resume_emission"):
				particles.remove_meta("stream_resume_emission")
				particles.emitting = true
	if Game.sceneAnimation.is_playing(): return
	if Game.state != Game.State.Shop and not loading.get("shop", false): unload("shop")
	if Game.state != Game.State.Combat and not loading.get("combat", false): unload("combat")
