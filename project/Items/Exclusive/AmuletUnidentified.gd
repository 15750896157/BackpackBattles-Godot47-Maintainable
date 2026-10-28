extends Item

var revealPulseScene = load("res://Items/Animations/RevealPulse.tscn")
const revealSound = preload("res://Assets/Sound/Reveal.ogg")

func _ready():
	super._ready()
	connect("dropped", Callable(self, "onDropped"))

func onDropped(dropRes):
	if (wasAddedToInventory(dropRes) or
		dropRes == DropResult.AddedToStorageBox):

		prepareReplacement()
		call_deferred("identifyAmulet", dropRes)

func identifyAmulet(dropResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAmuletUnidentified.identifyAmulet(self, dropResult)

func getRelatedItemColumns() -> int:
	return 4

func getRelatedItemHeight() -> int:
	return 100
