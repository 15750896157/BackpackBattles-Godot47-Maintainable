extends Node2D
## Compatibility handle; the active local UI owns each modal's actual lifetime.
var kind: String
var isOpen: bool = false
func canOpen():
	return not InputBlocker.isActive() and not is_instance_valid(Game.draggedItem)
func open():
	match kind:
		"crafting": Expedition.show_crafting()
		"settings": Expedition.show_settings()
		"history": Expedition.show_combat_log()
func close():
	Expedition.close_popup()
func closed():
	isOpen = false
