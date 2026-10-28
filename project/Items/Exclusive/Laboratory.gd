extends Item

var phase: int
var typesDict: Dictionary
var fluidTween: Tween

@onready var fluid = $Icon/Fluid
@onready var fluidMat = fluid.material

const params = {
	"luckt": 1,
	"heatt": 4,
	"heat_bonus": 1,
	"heat": 4,
	"spikest": 6,
	"spikes_bonus": 1,
	"spikes": 8,
	"regent": 8,
	"regen_bonus": 1,
	"regen": 10,
	"vampirism": 12,
	"vamp_bonus": 1,
	"vampt": 10,
	"empower_bonus": 1,
	"empower": 14
}

func _ready():
	super._ready()
	phase = - 1
	switchGradient()

func onShopEntered():
	onStateChanged( - 1)

func getDescription(wrapInColor = true) -> String:
	return load("res://Runtime/Behavior/Items/Exclusive/LaboratoryBehavior.gd").getDescription(self, wrapInColor)

func onPreCombatStart():
	setState(0)
	typesDict = countTypes(getAffectedItems())

func trigger():
	setState(phase + 1)

	super.trigger()

func canAffect(item):
	return load("res://Runtime/Behavior/Items/Exclusive/LaboratoryBehavior.gd").canAffect(self, item)

func doCooldownEffect():
	return load("res://Runtime/Behavior/Items/Exclusive/LaboratoryBehavior.gd").doCooldownEffect(self)

func onStateChanged(_phase: int):
	return load("res://Runtime/Behavior/Items/Exclusive/LaboratoryBehavior.gd").onStateChanged(self, _phase)

const flashColor = Color(1.3, 1.3, 1.3)
const DUR = 0.2

const gradients = [
	preload("res://Items/Exclusive/Materials/LaboratoryGradient1.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryGradient2.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryGradient3.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryGradient4.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryGradient5.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryGradient6.tres"),
	preload("res://Items/Exclusive/Materials/LaboratoryDefaultGradient.tres")
]

func switchGradient():
	fluidMat.set_shader_parameter("fade", 0.0)
	fluidMat.set_shader_parameter("gradient", gradients[phase])
