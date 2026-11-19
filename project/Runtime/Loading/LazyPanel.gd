extends Node2D
## Compatibility handle; the active local UI owns each modal's actual lifetime.
var kind: String
var isOpen: bool = false
func canOpen():
	return not InputBlocker.isActive() and not is_instance_valid(Game.draggedItem)
func open():
	# 启动窗口期（initialized 置位前）preferences/menus 尚未就位，
	# 此时任何 options/手柄幻影输入都不允许弹模态，否则 Nil 调用炸 stderr。
	if not Expedition.initialized: return
	match kind:
		"crafting": Expedition.show_crafting()
		"settings": Expedition.show_settings()
		"history": Expedition.show_combat_log()
func close():
	Expedition.close_popup()
func closed():
	isOpen = false
