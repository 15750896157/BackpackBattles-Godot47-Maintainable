extends Item

@onready var collarDescriptors = [
	ItemBook.getDescriptor("Acorn Collar"),
	ItemBook.getDescriptor("Magic Collar"),
	ItemBook.getDescriptor("Holy Collar"),
	ItemBook.getDescriptor("Vampiric Collar")
]

@onready var acornCollarDescriptor = collarDescriptors[0]
@onready var critwoodStaffDescriptor = ItemBook.getDescriptor("Critwood Staff")
@onready var staminaReduction = - getP("stamina2")

var affectedDescriptors

var boostedCollars = 0

func _ready():
	super._ready()
	affectedDescriptors = Util.arrayAsIndexDict(collarDescriptors)
	affectedDescriptors[critwoodStaffDescriptor] = 4

func getData():
	return boostedCollars

func setData(data):
	if data != null:
		boostedCollars = data

func onBought():
	boostedCollars = 1

func canAffect_global(item):
	return item.descriptor in affectedDescriptors

func onItemInstantiated(item):
	if (placed and
		item is RangerCollar and

		item.isOwnable()):
			item.activateExtendedAffectedCells()

func onAddToInventory():
	call_deferred("onAddToInventory_deferred")

func onAddToInventory_deferred():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAcornAce.onAddToInventory_deferred(self)

func onRemoveFromInventory():
	call_deferred("onRemoveFromInventory_deferred")

func onRemoveFromInventory_deferred():
	if isOwnable():
		for descr in collarDescriptors:
			for collar in ItemBook.getItemsOnScreenOfType(descr):
				collar.deactivateExtendedAffectedCells()

func onPrepare():
	for staff in getAllInInventoryOfType(critwoodStaffDescriptor):
		staff.changeStaminaFactor(staminaReduction)

func onItemRoll(descr):
	if descr == acornCollarDescriptor and boostedCollars > 0:
		ItemBook.multiplyWeight(1.5)

func onItemRolled(descr):
	if descr == acornCollarDescriptor:
		boostedCollars -= 1
