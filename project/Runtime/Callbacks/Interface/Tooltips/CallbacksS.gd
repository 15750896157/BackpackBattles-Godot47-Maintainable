extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForSimpleTooltip:
	const Receiver = preload("res://Interface/Tooltips/SimpleTooltip.gd")

	static func setParams(subject: Receiver, header, description):
		if Expedition.enabled and Expedition.db != null and subject.has_meta("pve_description_key"):
			description = Expedition.t(str(subject.get_meta("pve_description_key")))
		if header == "":
			subject.nameLabel.hide()
		else:
			subject.nameLabel.show()
			subject.nameLabel.text = subject.centerStr + subject.replaceReferences(subject.highlight(header), 40)
		subject.descrLabel.text = subject.replaceReferences(subject.highlight(description))
		Util.localizeFonts(subject)

class ForSubclassSubtooltip:
	const Receiver = preload("res://Interface/Tooltips/SubclassSubtooltip.gd")

	static func setSubclass(subject: Receiver, descriptor):
		if subject.item != null:
			subject.item.discard()

		subject.label.text = Game.getTranslatedSubclassName(descriptor.startsSubclass)
		subject.item = ItemBook.instantiateItem_pooled(descriptor)
		subject.item.ownerType = subject.item.Owner.Tooltip
		subject.itemNode.add_child(subject.item)
		subject.item.initTooltip()
		subject.item.scaleToFit(subject.maxSize, 0.8)
		subject.item.position = subject.item.getSpriteOffset()
