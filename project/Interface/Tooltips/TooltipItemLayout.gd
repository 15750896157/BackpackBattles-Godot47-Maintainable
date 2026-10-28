extends Control

const MARGIN = 20
var addedItems = []

func addItem(descriptor, maxSize, tooltip, defaultScaling = 0.7):
	return load("res://Runtime/Callbacks/Interface/Tooltips/CallbacksT.gd").ForTooltipItemLayout.addItem(self, descriptor, maxSize, tooltip, defaultScaling)

func enableFocus():
	for node in addedItems:
		if not node is Control:
			node.enableFocus()
			node.enableTooltip()
			node.showClickArea()

func discard():

	for node in addedItems:
		if not node is Control:
			node.owningBuildIntoRecipesTooltip = null
			node.discard()
