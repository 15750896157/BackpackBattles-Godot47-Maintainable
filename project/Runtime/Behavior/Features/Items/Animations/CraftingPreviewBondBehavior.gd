extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Animations/CraftingPreviewBond.gd")

static func create(subject: Receiver, _startNode, _endNode, flip):
	subject.startNode = _startNode
	subject.endNode = _endNode
	subject.sprite.flip_h = flip
	Util.killTween(subject.tween)
	subject.tween = subject.create_tween()
	subject.tween.tween_property(subject.sprite.material, "shader_parameter/laserSize", 0.24, subject.CHANGE_DUR)
	subject.orient()
	subject.set_physics_process(true)

static func orient(subject: Receiver):
	var startPos = subject.startNode.getCraftingPreviewPosition()
	var endPos = subject.endNode.getCraftingPreviewPosition()
	var dif = endPos - startPos
	var length = dif.length()
	subject.global_position = startPos
	subject.look_at(endPos)
	subject.z_index = Util.getGlobalZ(subject.startNode) + 1

	Util.stretchSpriteToWidth(subject.sprite, min(80, length))
	subject.sprite.material.set_shader_parameter("xStretch", subject.sprite.scale.x * 3.13)

static func breakBond(subject: Receiver):
	Util.killTween(subject.tween)
	subject.tween = subject.create_tween()
	subject.tween.tween_property(subject.sprite.material, "shader_parameter/laserSize", subject.MIN_STRENGTH, subject.CHANGE_DUR)
	subject.tween.tween_callback(Callable(subject, "returnToObjectPool"))
