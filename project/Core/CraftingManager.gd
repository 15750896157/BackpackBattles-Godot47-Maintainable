extends Node

signal recipes_updated

var craftingPreviewBondScene = load("res://Items/CraftingPreviewBond.tscn")

var itemsAvailablePending = []
var itemsRemovedPending = []
var updatePending = false
var fusionPreviews = []

func itemAdded(item):
	return

func itemRemoved(item):
	return

func itemShifted(item):

	itemRemoved(item)
	itemAdded(item)

func updateRecipes():
	itemsAvailablePending.clear()
	itemsRemovedPending.clear()
	updatePending = false
	return

func addIngredient(baseItem, recipe, ingredient):
	baseItem.addBondedIngredient(recipe, ingredient)
	ingredient.addToBaseItem(baseItem)

func previewFusionToItem(baseItem):
	return

func createFusionPreview(item1, item2, focusItem):
	return

func hideFusionPreviews(stopOrientation = false):

	for preview in fusionPreviews:

		preview.breakBond()
		if stopOrientation:
			preview.stopOrientation()
	fusionPreviews.clear()

# Recovered crafting visuals display canonical, manually confirmed recipe pairs.
var pve_candidate_bonds: Dictionary = {}

func pve_candidates() -> Array:
	if Expedition.flow == null or Expedition.flow.run.is_empty(): return []
	var result: Array = []
	for candidate in Expedition.flow.crafting.candidates(Expedition.flow.run.build, int(Expedition.flow.run.act)):
		var copy = candidate.duplicate(true)
		copy["material_entries"] = []
		for uid in candidate.material_uids:
			copy.material_entries.append(Expedition.flow.placement.find(Expedition.flow.run.build, str(uid)).get("entry", {}))
		var preview = Expedition.flow.crafting.preview(Expedition.flow.run, str(candidate.recipe_id), {"material_uids": candidate.material_uids})
		copy["pending"] = bool(preview.get("pending", false))
		copy["result_entry"] = preview.get("entry", {})
		copy["preview_ok"] = bool(preview.get("ok", false))
		copy["output_cells"] = Expedition.flow.placement.cells(copy.result_entry) if not copy.result_entry.is_empty() else []
		result.append(copy)
	return result

func pve_clear_candidates():
	for bonds in pve_candidate_bonds.values():
		for bond in bonds:
			if is_instance_valid(bond):
				bond.stopOrientation()
				bond.returnToObjectPool()
	pve_candidate_bonds.clear()

func pve_refresh_candidates():
	if not Expedition.initialized or Expedition.flow.run.is_empty() or Game.state != Game.State.Shop or Expedition.flow.screen_state != "SHOP_PREPARE":
		pve_clear_candidates(); return
	if not Game.is_connected("shop_closed", Callable(self, "pve_clear_candidates")): Game.connect("shop_closed", Callable(self, "pve_clear_candidates"))
	if not Game.is_connected("returned_to_title", Callable(self, "pve_clear_candidates")): Game.connect("returned_to_title", Callable(self, "pve_clear_candidates"))
	var wanted = {}
	for candidate in pve_candidates().slice(0, 4):
		var key = str(candidate.recipe_id) + ":" + "|".join(candidate.material_uids)
		wanted[key] = true
		if pve_candidate_bonds.has(key): continue
		var materials = []
		for uid in candidate.material_uids:
			for item in Game.PLAYER.INVENTORY.items:
				if str(item.get_meta("pve_uid", "")) == str(uid): materials.append(item); break
		if materials.size() != 2: continue
		var bonds = []
		for reverse in [false, true]:
			var visual = ObjectPool.instantiate(craftingPreviewBondScene)
			Game.playerNode.add_child(visual)
			visual.create(materials[0], materials[1], reverse)
			bonds.append(visual)
		pve_candidate_bonds[key] = bonds
	for key in pve_candidate_bonds.keys():
		if wanted.has(key): continue
		for bond in pve_candidate_bonds[key]:
			if is_instance_valid(bond): bond.stopOrientation(); bond.returnToObjectPool()
		pve_candidate_bonds.erase(key)
