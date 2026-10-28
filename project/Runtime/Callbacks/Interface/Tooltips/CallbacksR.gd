extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForRelatedItems:
	const Receiver = preload("res://Interface/Tooltips/RelatedItems.gd")

	static func setItem(subject: Receiver, item, tooltip):
		var relatedItems = item.getRelatedItems()
		var maxRowHeight = item.getRelatedItemHeight()
		var itemsPerRow = int(min(item.getRelatedItemColumns(), relatedItems.size()))

		subject.custom_minimum_size.x = subject.maxWidth

		var usableWidth = subject.maxWidth - subject.MARGIN * 0.5
		var itemWidth = usableWidth / itemsPerRow
		var itemSize = Vector2(itemWidth, maxRowHeight - subject.MARGIN * 0.5)

		var rowI = 0
		var columnI = 0
		var widestRow = 0
		var rowWidth = 0

		for descriptor in relatedItems:

			var relatedItem = subject.addItem(descriptor, itemSize, tooltip)
			subject.addedItems.push_back(relatedItem)
			var actualSize = relatedItem.getTextureSize()
			rowWidth += itemWidth

			relatedItem.position = Vector2(columnI * itemWidth + 0.5 * itemWidth,
				subject.header.size.y + rowI * maxRowHeight + 0.5 * maxRowHeight)

			columnI += 1
			if columnI == itemsPerRow:
				columnI = 0
				rowI += 1
				if rowWidth > widestRow:
					widestRow = rowWidth
				rowWidth = 0

		if rowWidth > widestRow:
			widestRow = rowWidth

		var slack = usableWidth - widestRow
		for related_item in subject.addedItems:
			related_item.position.x += slack * 0.5

		var numRows = ceil(relatedItems.size() / float(itemsPerRow))
		subject.custom_minimum_size.y = subject.header.size.y + maxRowHeight * numRows + 20
