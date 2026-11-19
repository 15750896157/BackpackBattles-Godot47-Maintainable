extends RefCounted
## Visual mappings only. No definition, footprint, save or combat-rule changes.
const ROOT = "res://Art/Supplied20261102/"
const CURRENT=preload("res://PvE/Art/NewArtCatalog.gd")
const REFERENCE = "res://Art/Reference20261102/"
const REFERENCE_UI = ["title", "title_logo", "title_hero", "title_book", "loading_base", "loading_fill", "loading_icon", "button", "button_blue", "button_red", "hand", "selection", "previous", "next", "back", "selection_shadow", "window", "settings_plate", "close", "check", "checkbox", "highlight", "slider_fill", "slider_base", "slider_knob", "ornament", "shop", "sell", "refresh", "merchant", "codex", "battle", "storage_mat", "journey", "table", "price", "sale", "shelf", "cell", "cell_empty", "bag9", "name", "play", "pause", "shadow", "health", "stamina", "plate1", "plate2", "plate3", "settings", "timeline_base", "timeline_fill"]
const ITEMS = ["utility_knife", "iron_sword", "broad_axe", "heavy_cleaver", "hunting_spear", "plated_vest", "leather_wrap", "tower_shield", "travel_ration", "sharpening_stone", "merchant_token", "focus_prism", "ember_stone", "glass_bead", "field_manual", "salvage_pouch", "duelist_mark", "layered_plates", "retaliation_spikes"]
const UI = ["merchant", "table", "shelf", "storage_mat", "sell", "refresh", "price", "sale", "codex", "journey", "battle", "name", "plate1", "plate2", "plate3", "health", "stamina", "play", "pause", "settings", "timeline_base", "timeline_fill", "shadow", "cell", "cell_empty", "bag9", "hand", "title", "button", "button_blue", "button_red", "camp", "selection"]
const STATUS = {"Poison":"poison", "Heat":"burn", "Vampirism":"lifesteal", "Spikes":"spikes", "Block":"armor", "Empower":"resistance"}

static func item_path(id: String) -> String:
	return CURRENT.item_path(id)

static func ui_path(key: String) -> String:
	if key in CURRENT.LATEST_UI:return CURRENT.LATEST+key+".png"
	if key in CURRENT.REFRESH_UI:return CURRENT.REFRESH+"ui/"+key+".png"
	if CURRENT.UI.has(key):return ROOT+CURRENT.UI[key]
	if key == "bag4": return REFERENCE+"bag4.png"
	if key in REFERENCE_UI: return REFERENCE+key+".png"
	return "res://Art/Supplied20261028/ui/"+key+".png" if key in UI else ""

static func player_key(character_class: int = -1) -> String:
	if Expedition.active and not Expedition.flow.run.is_empty(): return str(Expedition.flow.run.character_id)
	var art_key = load("res://PvE/ClassRegistry.gd").art_key_for_index(character_class)
	return art_key if not art_key.is_empty() else "armorer"

static func actor_path(key: String) -> String:
	return CURRENT.actor_path(key)

static func shop_actor_path(key: String) -> String:
	return CURRENT.shop_actor_path(key)

static func status_path(key:String)->String:
	return CURRENT.status_path(key)
