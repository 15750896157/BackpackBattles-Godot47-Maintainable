extends LocalizedControl

const RIGHT_BORDER = 1890
const TOP_BORDER = 30

func init(key: String, control: Node, offset: Vector2 = Vector2.ZERO):
	translationKey = key
	updateLocale()
	call_deferred("positionLabel", control, offset)

func positionLabel(control, offset):
	return load("res://Runtime/Callbacks/Interface/CallbacksT.gd").ForTooltipLabel.positionLabel(self, control, offset)

