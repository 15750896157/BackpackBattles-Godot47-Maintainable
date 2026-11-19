extends Resource
class_name StartingItem

@export var itemName: String
@export var faceDirection: Item.FaceDirection = Item.FaceDirection.UP
@export var topLeftCell: Vector2

func getTranslatedItemName() -> String:
	return Util.tra(itemName + "_NAME")
