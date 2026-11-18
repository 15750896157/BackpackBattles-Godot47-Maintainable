extends RefCounted
## Read-only visual vocabulary. Never rolls the run RNG or changes definitions.
const RARITIES = {"common":Color("d7e8ed"),"uncommon":Color("82e8ac"),"rare":Color("64bcff"),"epic":Color("ce8dff"),"legendary":Color("ffc46b")}
const ELEMENTS = {"ember":Color("ff8548"),"toxin":Color("9cec76"),"arcane":Color("b393ff"),"holy":Color("ffe6a0"),"guard":Color("76d8ff"),"heal":Color("85efbd")}

static func profile(definition: Dictionary) -> Dictionary:
	var id = str(definition.get("id", ""))
	var tags = str(definition.get("tags", "")).split("|")
	var kind = "slash"
	if "ranged" in tags or "bow" in id: kind = "arrow"
	elif "heavy" in tags or "axe" in id or "maul" in id: kind = "heavy"
	elif "staff" in id or "prism" in id or "codex" in id: kind = "arcane"
	elif "armor" in tags or "shield" in id or "vest" in id: kind = "guard"
	elif "healing" in tags and "weapon" not in tags: kind = "heal"
	var element = ""
	if "burn" in tags or "fire" in id or "ember" in id or "flint" in id: element = "ember"
	elif "poison" in tags: element = "toxin"
	elif "holy" in id or "cross" in id or "radiant" in id: element = "holy"
	elif kind in ["guard","heal","arcane"]: element = kind
	var rarity = str(definition.get("rarity", "common"))
	var rank = int({"common":0,"uncommon":1,"rare":2,"epic":3,"legendary":4}.get(rarity,0))
	var tier_color: Color = RARITIES.get(rarity,RARITIES.common)
	var color: Color = ELEMENTS.get(element,tier_color)
	# Element keeps its identity; a thin rarity rim carries the tier cue.
	var magical = element in ["ember","toxin","holy"] or kind == "arcane"
	for hint in ["gem","crystal","flint","staff","elven_tear","magic","demonic"]:
		if hint in id: magical = true
	var glow = 0.0 if rank == 0 and not magical else 0.12 + rank * 0.075
	return {"kind":kind,"element":element,"color":color,"rarity_color":tier_color,"rank":rank,"glow":glow,"weapon":"weapon" in tags}

static func event_profile(event: Dictionary, db, result: Dictionary) -> Dictionary:
	var side = int(event.get("source_side",0))
	var uid = str(event.get("source_uid",event.get("source","")))
	var id = ""
	var actor = Game.PLAYER if side == 0 else Game.OPPONENT
	if is_instance_valid(actor) and actor.INVENTORY != null:
		for item in actor.INVENTORY.getItems():
			if str(item.get_meta("pve_uid","")) == uid:
				id = str(item.get_meta("pve_definition_id","")); break
	if id.is_empty():
		for row in result.get("item_stats_by_instance_id",{}).values():
			if int(row.get("side",-1)) == side and str(row.get("instance_id","")) == uid:
				id = str(row.get("definition_id",row.get("item_id",""))); break
	var value = profile(db.get_row("items",id))
	var status = str(event.get("status_id",""))
	if status in ["poison","burn"]:
		value.element = "toxin" if status == "poison" else "ember"
		value.color = ELEMENTS[value.element]
	return value
