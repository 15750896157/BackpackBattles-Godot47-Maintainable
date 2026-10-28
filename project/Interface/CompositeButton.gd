extends FocusGrabbingButton

@export var labelPath: NodePath
@onready var hoverLabel = get_node_or_null(labelPath)
var hoverLabel_colorPath
var hoverLabel_defaultColor
const disabledColor = Color(0.693359, 0.65267, 0.601273)

@export var iconPath: NodePath
@onready var hoverIcon = get_node_or_null(iconPath)
var iconNormal
@export var iconHovered: Texture2D
@export var iconDisabled: Texture2D
@export var iconPressed: Texture2D

func _ready():
	super._ready()
	if hoverLabel != null:
		if hoverLabel is Label:
			hoverLabel_colorPath = "theme_override_colors/font_color"
		else:
			hoverLabel_colorPath = "theme_override_colors/default_color"

		hoverLabel_defaultColor = hoverLabel.get(hoverLabel_colorPath)

	if hoverIcon != null:
		iconNormal = hoverIcon.texture

func onHover():
	super.onHover()
	if hoverLabel != null:
		hoverLabel.set(hoverLabel_colorPath, Util.paramColor)

	if hoverIcon != null:
		if iconHovered != null:
			hoverIcon.texture = iconHovered

func onHoverEnd():
	super.onHoverEnd()
	if hoverLabel != null:
		hoverLabel.set(hoverLabel_colorPath, hoverLabel_defaultColor)

	if hoverIcon != null:
		if iconHovered != null:
			hoverIcon.texture = iconNormal

func onPressed():
	super.onPressed()
	if hoverIcon != null:
		if iconPressed != null:
			if button_pressed:
				hoverIcon.texture = iconPressed
			else:
				hoverIcon.texture = iconNormal

func enable():
	super.enable()
	if hoverIcon != null:
		if iconDisabled != null:
			hoverIcon.texture = iconNormal

	if hoverLabel != null:
		hoverLabel.set(hoverLabel_colorPath, hoverLabel_defaultColor)

func disable():
	super.disable()
	if hoverIcon != null:
		if iconDisabled != null:
			hoverIcon.texture = iconDisabled

	if hoverLabel != null:
		hoverLabel.set(hoverLabel_colorPath, disabledColor)
