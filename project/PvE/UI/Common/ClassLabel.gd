extends LocalizedControl

@onready var tooltipArea = get_node_or_null("TooltipArea")
@onready var subclassParticles = $SubclassParticles
@onready var icon = $ClassIcon

func _ready() -> void :
	super._ready()
	Game.connect("character_changed", Callable(self, "updateText"))
	Game.connect("item_bought", Callable(self, "onItemBought"))
	Game.connect("pre_shop_opened_from_combat", Callable(self, "updateText"))

	Util.callNextFrame(self, "updateText")

func updateText(subclass = ""):
	if not is_instance_valid(Game.PLAYER) or Game.PLAYER.INVENTORY == null: return

	icon.texture = Game.classIcons[Game.curClass]
	icon.position = Vector2(-30, size.y * 0.5)
	translationKey = ""
	set("text", Game.getClassName())
	set("theme_override_colors/font_color", Game.getNativeClassColor())
	if tooltipArea:
		tooltipArea.keyword = Game.getClassInternalName()
		tooltipArea.params = {"items": ""}
		tooltipArea.show()
	return

func onItemBought(item, _onSale):
	updateText()
	return
