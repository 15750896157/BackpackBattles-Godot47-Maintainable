extends RichTextLabel
class_name CombatLogLine

var poolingHandle
var event: CombatEvent
var player: bool
var minimized: bool
var state: int
var cachedText: String

enum State{
	Normal = 0,
	Hovered = 1,
	Connected = 2,
	Tooltip = 3
}

func preset():
	add_to_group("Localized")
	Util.localizeFonts(self)

func _ready() -> void :
	Util.localizeFonts(self)

func updateLocale():
	cachedText = event.asText()

	if not minimized:
		text = cachedText

func getText() -> String:
	return cachedText

func setEvent(_event):
	event = _event
	player = event.getMainActor() == Character.ID.PLAYER

	setStylebox(State.Normal)
	updateLocale()

func setMinimized(_minimized):
	if minimized == _minimized: return

	minimized = _minimized

	if minimized:
		text = ""
		fit_content = false
		custom_minimum_size.y = 5
		size.y = 5

	else:
		text = cachedText
		fit_content = true

func getItem():
	var origin = event.getOrigin()
	if origin and origin is Item:
		return origin
	return null

func getSource():
	var origin = event.getOrigin()
	if origin and typeof(origin) == TYPE_INT:
		return origin
	return null

func getType():
	return event.type

func onHovered():
	if Game.fightEnded and state != State.Tooltip:
		Game.combatLog.onLineHovered(self)
		setStylebox(State.Hovered)

func onConnectedHovered():
	setStylebox(State.Connected)

func onHoverEnd():
	setStylebox(State.Normal)
	if getItem() or getSource():
		Game.combatLog.unhighlightItem()

func onConnectedHoverEnd():
	setStylebox(State.Normal)
	Game.combatLog.onLineHoverEnd()

func setStylebox(_state: int):

	state = _state
	if not player:
		set("theme_override_colors/default_color", Color.WHITE)
	else:
		set("theme_override_colors/default_color", Game.BROWN)

	var faded = false
	if state != State.Tooltip:
		if event.type == Game.EventType.Activation:
			faded = true

	set("theme_override_styles/normal", Game.combatLog.getStylebox(player, state, faded))
