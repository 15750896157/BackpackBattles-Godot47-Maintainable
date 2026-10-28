class_name ShopState
extends RefCounted

var db

func _init(content = null):
	db = content

func create() -> Dictionary:
	return {"slots": [], "refresh_count": 0, "bag_pity_count": 0, "discount_slot": -1, "visit": -1}

func locked_carry(shop: Dictionary) -> Array:
	var result: Array = []
	for index in range(shop.get("slots", []).size()):
		var slot = shop.slots[index]
		if bool(slot.get("locked", false)) and not bool(slot.get("sold", false)):
			var copy = slot.duplicate(true)
			copy["slot_index"] = index
			copy["locked"] = false
			copy["lock_remaining"] = 0
			copy["carried"] = true
			result.append(copy)
	return result
