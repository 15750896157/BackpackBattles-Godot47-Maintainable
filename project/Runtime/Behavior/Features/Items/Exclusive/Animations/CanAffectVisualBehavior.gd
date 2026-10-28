extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/Animations/CanAffectVisual.gd")

static func preset(subject: Receiver):
	subject.sprites[0] = subject.get_node("Primary")
	subject.sprites[2] = subject.get_node("Secondary")
	subject.sprites[4] = subject.get_node("Tertiary")
	subject.sprites[6] = subject.get_node("Bag")
	subject.sprites[7] = subject.get_node("Lightning")
	for color in subject.sprites:
		subject.sprites[color].hide()

static func setColorActive(subject: Receiver, color):
	subject.sprites[color].show()
	if color == 2:
		if subject.sprites[0].visible:
			subject.sprites[2].position = subject.secondPos
		else:
			subject.sprites[2].position = Vector2.ZERO
	elif color == 4:
		var numVisible = int(subject.sprites[0].visible) + int(subject.sprites[2].visible)
		if numVisible == 2:
			subject.sprites[4].position = subject.thirdPos
		elif numVisible == 1:
			subject.sprites[4].position = subject.secondPos
		else:
			subject.sprites[4].position = Vector2.ZERO
