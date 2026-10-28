extends RefCounted
## Acceptance waits for the real scheduler, rather than assuming synchronous IO.
static func wait_idle(tree: SceneTree, timeout: float = 25.0) -> bool:
	var deadline = Time.get_ticks_msec() + int(timeout * 1000)
	var stable = 0
	while Time.get_ticks_msec() < deadline:
		var busy = not AssetStream.pending.is_empty() or not AssetStream.inflight.is_empty() or not AssetStream.jobs.is_empty()
		busy = busy or Expedition.syncing or Expedition.entering_shop or Expedition.combat_loading
		if Expedition.art != null and Expedition.art.curtain != null: busy = busy or Expedition.art.curtain.busy
		if Expedition.transitions != null:
			busy = busy or is_instance_valid(Expedition.transitions.closing_ghost)
			var popup = Expedition.transitions.popup_tween
			busy = busy or (popup != null and popup.is_valid() and popup.is_running())
		if is_instance_valid(Game.wardrobe): busy = busy or Game.wardrobe.skin_building
		stable = 0 if busy else stable + 1
		if stable >= 4: return true
		await tree.process_frame
	push_error("Timed out waiting for actual asset/view work: " + JSON.stringify({"assets":AssetStream.stats(),"syncing":Expedition.syncing,"entering_shop":Expedition.entering_shop,"combat_loading":Expedition.combat_loading,"curtain":Expedition.art.curtain.busy,"view":Expedition.art.view,"ready_view":Expedition.art.ready_kind,"game_state":Game.state,"animation":Game.sceneAnimation.current_animation,"animation_playing":Game.sceneAnimation.is_playing(),"wardrobe":Game.wardrobe.skin_building if is_instance_valid(Game.wardrobe) else false,"flow":Expedition.flow.screen_state}))
	return false
