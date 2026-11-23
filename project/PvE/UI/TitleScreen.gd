extends Control
## The scene owns layout and feedback. The host supplies the model, art and font.

const TitleVM = preload("res://Code/Runtime/ViewModel/TitleVM.gd")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const ART_KEYS = [
	"title", "title_logo", "select_armorer", "select_archer", "select_alchemist",
	"title_book", "button", "button_blue", "button_red", "settings",
]
const HOVER_TINT := Color(1.08, 1.06, 1.0)
const PRESS_TINT := Color(0.82, 0.82, 0.82)

var _model: TitleVM
var _art: Dictionary
var _font: Font

@onready var _background: TextureRect = $Ref_title
@onready var _logo: TextureRect = $Ref_title_logo
@onready var _portrait: TextureRect = $SavedPortrait
@onready var _settings: TextureButton = $TitleSettings
@onready var _codex: TextureButton = $TitleCodex
@onready var _start: TextureButton = $TitleStart
@onready var _exit: TextureButton = $TitleExit
@onready var _new_run: TextureButton = $TitleNewRun

func bind(model: TitleVM, art: Dictionary, font: Font) -> Error:
	if model == null or font == null:
		return ERR_INVALID_PARAMETER
	for key in ART_KEYS:
		if not art.get(key) is Texture2D:
			return ERR_INVALID_PARAMETER
	if is_inside_tree():
		_disconnect_model()
	_model = model
	_art = art.duplicate()
	_font = font
	if is_inside_tree():
		_connect_model()
	if is_node_ready():
		_apply_bindings()
	return OK

func _enter_tree() -> void:
	_connect_model()

func _exit_tree() -> void:
	_disconnect_model()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _model != null:
		_model.refresh()

func _connect_model() -> void:
	if _model == null:
		return
	_model.changed.connect(_render)
	_model.observe_run_saves()

func _disconnect_model() -> void:
	if _model == null:
		return
	_model.changed.disconnect(_render)
	_model.stop_observing_run_saves()

func _ready() -> void:
	for button: TextureButton in [_settings, _codex, _start, _exit, _new_run]:
		button.mouse_entered.connect(_hover.bind(button, HOVER_TINT))
		button.mouse_exited.connect(_hover.bind(button, Color.WHITE))
		button.button_down.connect(_set_press_tint.bind(button, PRESS_TINT))
		button.button_up.connect(_set_press_tint.bind(button, Color.WHITE))
	if _model != null:
		_apply_bindings()

func _apply_bindings() -> void:
	_background.texture = _art["title"]
	_logo.texture = _art["title_logo"]
	_settings.texture_normal = _art["settings"]
	_codex.texture_normal = _art["title_book"]
	_start.texture_normal = _art["button"]
	_exit.texture_normal = _art["button_blue"]
	_new_run.texture_normal = _art["button_red"]
	for button: TextureButton in [_settings, _codex, _start, _exit, _new_run]:
		button.disabled = false
	_render()

func _render() -> void:
	if not is_node_ready():
		return
	var state := _model.snapshot()
	var can_continue := bool(state.can_continue)
	var chinese := str(state.locale).begins_with("zh")
	_portrait.texture = _art.get("select_" + str(state.character_id)) if can_continue else null
	_portrait.visible = can_continue
	_new_run.visible = can_continue
	var primary := "开始游戏" if chinese else "Start game"
	if can_continue:
		primary = "继续游戏" if chinese else "Continue"
	_set_caption(_start, primary)
	_set_caption(_exit, "退出游戏" if chinese else "Exit game")
	_set_caption(_new_run, "结束当前对决" if chinese else "New expedition")

func _set_caption(button: TextureButton, caption: String) -> void:
	var label: Label = button.get_node("Caption")
	label.add_theme_font_override("font", _font)
	var size := 48
	while size > 16:
		var width := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if width <= label.size.x - 8 and _font.get_height(size) <= label.size.y:
			break
		size -= 1
	var snapped := int(REF.font_step(size))
	label.add_theme_font_size_override("font_size", snapped if snapped <= size else size)
	label.text = caption
	REF.center_label(label)
	button.set_meta("action_caption", caption)

func _hover(button: TextureButton, color: Color) -> void:
	var previous: Variant = button.get_meta("reference_feedback", null) if button.has_meta("reference_feedback") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := button.create_tween().set_ignore_time_scale(true)
	button.set_meta("reference_feedback", tween)
	tween.tween_property(button, "modulate", color, 0.1)

func _set_press_tint(button: TextureButton, color: Color) -> void:
	button.self_modulate = color

func _on_start() -> void:
	_model.start_or_continue()

func _on_exit() -> void:
	_model.quit_game()

func _on_new_run() -> void:
	_model.end_run()

func _on_settings() -> void:
	_model.open_settings()

func _on_codex() -> void:
	_model.open_codex()
