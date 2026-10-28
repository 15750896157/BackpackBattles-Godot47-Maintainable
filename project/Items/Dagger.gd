extends Weapon
class_name Dagger

func prepare():
	super.prepare()
	connectForCombat(opponent(), "character_stunned", "onStun")

func onStun(triggerEvent):
	attack(triggerEvent)
