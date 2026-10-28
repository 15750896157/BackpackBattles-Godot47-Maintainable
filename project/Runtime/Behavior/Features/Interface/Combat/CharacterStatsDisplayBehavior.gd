extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Combat/CharacterStatsDisplay.gd")

static func _ready(subject: Receiver):
	for stat in range(Character.Stat.ReflectStacks, Character.Stat.size()):
		var icon = ObjectPool.instantiate(subject.iconScene)
		subject.icons[stat] = icon
		subject.add_child(icon)
		icon.setStat(stat)

	Game.connect("combat_start", Callable(subject, "activateIcons"))

static func onStatChanged(subject: Receiver, stat: int, value):
	if not Game.STAT_DISPLAY_ENABLED: return
	if not stat in subject.icons: return

	var icon = subject.icons[stat]
	var wasActive = icon.active
	icon.setStatValue(value)
	if not wasActive and icon.active:
		icon.position = subject.getGridPosition(subject.activeIcons.size())
		subject.activeIcons.push_back(icon)
	elif wasActive and not icon.active:
		var index = subject.activeIcons.find(icon)
		Util.eassert(index != - 1)
		subject.activeIcons.remove_at(index)
		subject.repositionIcons(index)

static func repositionIcons(subject: Receiver, fromIndex: int):
	if fromIndex >= subject.activeIcons.size(): return

	subject.positionTween = Util.refreshTween(subject.positionTween).set_parallel(true)
	for iconI in range(fromIndex, subject.activeIcons.size()):
		subject.positionTween.tween_property(subject.activeIcons[iconI], "position",
			subject.getGridPosition(iconI), 0.2)
	subject.positionTween.set_speed_scale(0)
