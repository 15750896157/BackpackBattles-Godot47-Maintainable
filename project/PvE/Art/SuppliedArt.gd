extends RefCounted
## Visual mappings only. No definition, footprint, save or combat-rule changes.
const ROOT = "res://Art/Supplied20261028/"
const ITEMS = ["utility_knife", "iron_sword", "broad_axe", "heavy_cleaver", "hunting_spear", "plated_vest", "leather_wrap", "tower_shield", "travel_ration", "sharpening_stone", "merchant_token", "focus_prism", "ember_stone", "glass_bead", "field_manual", "salvage_pouch", "duelist_mark", "layered_plates", "retaliation_spikes"]
const UI = ["merchant", "table", "shelf", "storage_mat", "sell", "refresh", "price", "sale", "codex", "journey", "battle", "name", "plate1", "plate2", "plate3", "health", "stamina", "play", "pause", "settings", "timeline_base", "timeline_fill", "shadow", "cell", "cell_empty", "bag9", "hand", "title", "button", "button_blue", "button_red", "camp", "selection"]
const STATUS = {"Poison":"poison", "Heat":"burn", "Vampirism":"lifesteal", "Spikes":"spikes", "Block":"armor", "Empower":"resistance"}

static func item_path(id: String) -> String:
	return ROOT+"items/"+id+".png" if id in ITEMS else ""

static func ui_path(key: String) -> String:
	return ROOT+"ui/"+key+".png" if key in UI else ""

static func player_key(character_class: int = -1) -> String:
	if Expedition.active and not Expedition.flow.run.is_empty(): return str(Expedition.flow.run.character_id)
	return "alchemist" if character_class == Game.Classes_Full.Reaper else "armorer"

static func actor_path(key: String) -> String:
	return ROOT+"actors/"+key+".png"

static func shop_actor_path(key: String) -> String:
	return ROOT+"ui/shop_"+key+".png"
