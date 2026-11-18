extends CanvasLayer
## Binds the shared HUD. Screen-specific inventory and combat controls stay with their screens.

@onready var toolbar: HBoxContainer = $Toolbar
@onready var status: Label = $Status
@onready var tutorial_hint: Label = $TutorialHint

var _model: ViewModel
var _toast: Label

func bind(model: ViewModel, hud_theme: Theme, font: Font, font_scale: float, toast: Label) -> void:
	_model = model
	_toast = toast
	toolbar.theme = hud_theme
	status.theme = hud_theme
	var labels := {status: 22, tutorial_hint: 18, toast: 18}
	for label: Label in labels:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", roundi(labels[label] * font_scale))
	_model.changed.connect(_update_text)
	_update_text()

func set_run_controls_visible(value: bool) -> void:
	toolbar.visible = value
	status.visible = value

func _update_text() -> void:
	var model := _model.snapshot()
	status.text = model.status
	_toast.text = model.notice
