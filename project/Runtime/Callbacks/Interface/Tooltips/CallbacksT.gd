extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForTooltipItemLayout:
	const Receiver = preload("res://Interface/Tooltips/TooltipItemLayout.gd")

	static func addItem(subject: Receiver, descriptor, maxSize, tooltip, defaultScaling):
		var ingredient = descriptor.instantiate_pooled()
		ingredient.ownerType = ingredient.Owner.Tooltip
		subject.add_child(ingredient)
		ingredient.initTooltip()
		ingredient.scaleToFit(maxSize, defaultScaling)
		ingredient.owningBuildIntoRecipesTooltip = tooltip
		return ingredient
