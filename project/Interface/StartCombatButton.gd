extends FocusGrabbingButton

const activateTime = 0.5
const hoveredTexture = preload("res://Assets/Shop/Sign1_hovered.png")
const clickSound = preload("res://Assets/Sound/Thud5.wav")

@export var progress: float

@onready var animation = $AnimationPlayer
@onready var normalTexture = icon
@onready var progressMat = $Progress.material
@onready var pathFollow = $Path3D/PathFollow2D
@onready var pathParticles = $Path3D/PathFollow2D/PathParticles
@onready var storageHint = get_parent().get_node("Hints/StorageHint")
@onready var storageHintAni = storageHint.get_node("AnimationPlayer")
@onready var lampButton = get_parent().get_node("Lamp/Button")

var isPressed = false
var hovered = false
var enabled = true
var willFaceNoConnectionDarkReflection: bool

func _ready() -> void :
	super._ready()
	Game.connect("run_started", Callable(self, "onRunStarted"))
	Game.connect("switch_to_shop", Callable(self, "reset"))
	Game.connect("warp_cursor_shop", Callable(self, "onCursorWarp"))
	set_process(false)
	if Expedition.enabled:
		add_to_group("Localized")
		$StartLabel.translationKey = ""
		call_deferred("updateLocale")

func updateLocale():
	if Expedition.enabled and Expedition.db != null:
		$StartLabel.text = Expedition.t("ui.start_combat")
		$StartLabel.shrinkIfTooBig($StartLabel.text)

func onRunStarted():
	visible = (Game.curMode != Game.Mode.Lobbies)

func reset():
	set_pressed_no_signal(false)
	isPressed = false
	onHoverEnd()

func onHover():
	super.onHover()
	if not hovered:
		hovered = true
		if enabled:
			Game.onHoverInteractable(self)
			icon = hoveredTexture

func onHoverEnd():
	super.onHoverEnd()
	if hovered:
		hovered = false
		if enabled:
			icon = normalTexture
			Game.onHoverInteractableEnd(self)

func onButtonDown():
	if enabled:
		isPressed = true

func onButtonUp():
	isPressed = false

func _unhandled_input(event):
	if InputBlocker.isActive(): return

	if Util.isActionPressed_event(event, "start_battle"):
		activateButton()

func onPressed():
	if enabled and hovered:
		if Util.time > Game.lastItemDropTime + 0.5:
			activateButton()

func _gui_input(event):
	if event is InputEventScreenTouch and event.pressed:
		isPressed = true

func activateButton():
	if Game.isSwitchToCombatPossible() and Expedition.start_battle():
		Game.switchToCombat()
		Sound.playSound(clickSound, 6)
		showStorageHint()
	return

func playSwitchSound():
	Sound.playSound(Game.shopSceneNode.shopOpenSound, 0, 0.8)

func cancelSwitch():
	pathParticles.deactivate()
	set_process(false)

func finishSwitchingToCombat():
	return load("res://Runtime/Behavior/Interface/StartCombatButtonBehavior.gd").finishSwitchingToCombat(self)

func onAdFinished():
	Game.unpause(Game.PauseSource.Ad)
	Game.finishSwitchingToCombat()

func activateParticles():
	if Game.canCancelSwitch:
		set_process(true)
		pathParticles.activate()

func _process(delta: float) -> void :

	pathFollow.progress_ratio = progress

func disable():
	return load("res://Runtime/Behavior/Interface/StartCombatButtonBehavior.gd").disable(self)

func enable():
	enabled = true
	InputBlocker.setMouseFilter(self, Control.MOUSE_FILTER_STOP)
	InputBlocker.setMouseFilter(lampButton, Control.MOUSE_FILTER_STOP)

	if hovered:
		onHover()

func showStorageHint():
	return load("res://Runtime/Behavior/Interface/StartCombatButtonBehavior.gd").showStorageHint(self)

func onCursorWarp():
	Game.addPointOfInterest(global_position + pivot_offset)
