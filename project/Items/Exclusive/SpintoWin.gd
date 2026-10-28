extends Item

@onready var heat = int(getP("heat"))
@onready var luck = int(getP("luck"))
@onready var regen = int(getP("regen"))
@onready var mana = int(getP("mana"))
@onready var frame = $Icon/Frame

const colors = {
	FaceDirection.UP: Color(0.941176, 0.489231, 0.301961),
	FaceDirection.RIGHT: Color(0.301961, 0.941176, 0.41682),
	FaceDirection.DOWN: Color(0.941176, 0.301961, 0.513726),
	FaceDirection.LEFT: Color(0.320312, 0.466339, 1)
}

const neutralColor = Color(1, 1, 1, 0.364706)
@onready var skillLight = $Icon/SkillLight

func ready_deferred():
	super.ready_deferred()
	updateColor()
	frame.setRotationTarget( - sprite.global_rotation)

func updateColor():
	skillLight.modulate = colors[faceDirection]
	specificDragParticles[0].self_modulate = skillLight.modulate

func getDescription(wrapInColor = true):
	var descr = super.getDescription(wrapInColor)
	var colors = [Util.inactiveColor, Util.inactiveColor, Util.inactiveColor, Util.inactiveColor]
	var gold: int

	if placed:
		colors[faceDirection] = Util.modifiedColor

	descr = getModeDescription(descr, colors, false, wrapInColor)

	return descr

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpintoWin.doCooldownEffect(self)

func gainsStack(stackType) -> bool:
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpintoWin.gainsStack(self, stackType)

func rotateTo(targetRotation, duration = 0.15):
	super.rotateTo(targetRotation, duration)
	updateColor()

func setFaceDirectionInstant(_faceDirection):
	super.setFaceDirectionInstant(_faceDirection)
	frame.setRotationInstant( - sprite.global_rotation)
	updateColor()
