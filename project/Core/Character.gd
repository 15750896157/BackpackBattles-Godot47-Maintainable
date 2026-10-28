extends Node2D
class_name Character

signal class_changed
signal health_changed_ui
signal max_health_changed_ui
signal max_stamina_changed_ui
signal stamina_regen_changed_ui
signal gained_stamina_ui
signal used_stamina_ui
signal character_died
signal character_insufficient_stamina

enum ID{
	PLAYER = 0,
	OPPONENT = 1,
}

enum Stat{
	Health = 0,
	MaxHealth = 1,
	Stamina = 2,
	MaxStamina = 3,
	Invulnerable = 4,
	Stunned = 5,
	BattleRage = 6,

	ReflectStacks = 7,
	DebuffResistStacks = 8,
	CritStacks = 9,
	DodgeStacks = 10,
	CritResistStacks = 11,
	CritResistance = 12,
	StunResistance = 13,
	HealEfficiency = 14,
	DamageResistance = 15,
	MeleeDmgFactor = 16,
	RangedDmgFactor = 17,
	EffectDmgFactor = 18,
	Unhealing = 19,
	StaminaRegen = 20,
	MaxHealthGain = 21,
}

const inventoryScene = preload("res://Core/Inventory.tscn")
const AUTO_RAGE_DELAY = 5.0
const AUTO_RAGE_DUR = 4.0

var INVENTORY
var playerId: int
var characterClass = Game.Classes.Ranger
var characterName: String
var chibi = false
var opponent = null
var isDead: bool
var buffs: Dictionary
var maxHealth: float = 30.0
var curHealth: float
var temporaryMaxHealth: float = 0.0
var temporaryMaxHealthGain: float = 1.0
var baseMaxStamina: float
var maxStamina: float = 5.0
var curStamina: float
var temporaryMaxStamina: float = 0.0
var baseStaminaRegen: float = 1.0
var staminaRegen: float = baseStaminaRegen
var allowStaminaOverflow: bool = false
var stunnedDuration: float
var invulnerable: bool = false
var invulnerabilityItem = null
var unhealingAmount: float = 0.0
var healingEfficiency: float = 1.0
var damageResistance: float = 0.0
var damageReduction: int
var dodgeStacks: int = 0
var critResistance: float = 0.0
var critResistStacks: int = 0
var stunResistance: float = 0.0
var debuffResistStacks: int = 0

var debuffReflectStacks: int = 0
var buffProtectStacks: int = 0
var critTokens: int = 0
var battleRageBonusDur: float = 0.0
var bonusFatigueDamage = 0
var meleeSpikesLimit = 1.0
var rangedSpikesLimit = 0.0
var effectSpikesLimit = 0.0
var meleeVampirismLimit = 1.0
var rangedVampirismLimit = 0.0
var empowerDamage = 1.0
var typedDamageFactors = {}

var accuracyRng = BalancedRng.new()
var critRng = BalancedRng.new()
var critResistanceRng = BalancedRng.new()
var stunResistanceRng = BalancedRng.new()
var spikeDamageSource
var poisonDamageSource
var spriteAnimation
var idleAnimation
var idleAniDefaultSpeed
var attackTween
var combatDefaultPos: Vector2
var invulBubbleVisible = false
var blindingLightActive = false
var attackMovingForward: bool
var attackSoundReadyTime = 0.0
var tickCounter: int
var autoRageItem = null

@onready var animation = $AnimationPlayer
@onready var combatAnimation = $CombatAnimation
@onready var spriteNode = $Mirroring/Sprite2D
@onready var tickTimer = $TickTimer
@onready var sprite = $Mirroring/Sprite2D/Sprite2D
@onready var idleAniSpeedTimer = $Mirroring/Sprite2D/AnimationSpeedTimer
@onready var damageAnimation = $HitAnimation
@onready var audioPlayer = $AudioStreamPlayer
@onready var invuBubbleAni = $Mirroring/Sprite2D/InvulnerabilityBubble/AnimationPlayer
@onready var invulnerabilityTimer = $InvulnerabilityTimer
@onready var battleRageTimer = $BattleRageTimer
@onready var autoRageTimer = $AutoRageTimer
@onready var battleRageAnimation = $Mirroring/Sprite2D/BattleRageAura/AnimationPlayer
@onready var battleRageParticles = $Mirroring/Sprite2D/BattleRageParticles
@onready var battleRageAura = $Mirroring/Sprite2D/BattleRageAura
@onready var statsDisplay = $CombatUI/StatsDisplay
@onready var loseParticles = $Mirroring/LoseParticles
@onready var winParticles = $Mirroring/WinParticles
@onready var nameBanner = $CombatUI/Sheet/NameBanner
@onready var randomClassParticles = get_node_or_null("Mirroring/Sprite2D/RandomClassParticles")

@onready var nameLineEdit = get_node_or_null("ShopUI/NameLineEdit")
@onready var nameLabel = $CombatUI/Name
@onready var goldPos = get_node_or_null("ShopUI/GoldPos")
@onready var damNumberPos = $Mirroring/Sprite2D/DamageNumberPosition
@onready var clickArea = $Mirroring/Sprite2D/Button
@onready var levelUpParticles = get_node_or_null("Mirroring/Sprite2D/LevelUpParticles")

func _ready() -> void :
	load("res://Runtime/Behavior/Core/CharacterBehavior.gd")._ready(self)

func isPlayer():
	return playerId == ID.PLAYER

func setOpponent(_opponent):
	opponent = _opponent

func setCharacterName(_name: String):
	characterName = _name
	if playerId == ID.PLAYER:
		nameLineEdit.text = characterName
	nameLabel.text = characterName

func showCharacterName():
	nameLabel.text = characterName

func hideCharacterName():
	nameLabel.text = Util.tra("OPPONENT_HIDDEN")

func getClass() -> int:
	return characterClass

func isChibi() -> int:
	return chibi

func setClass(_class: int, _chibi: bool):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").setClass(self, _class, _chibi)

func setClassResource(classResource: CharacterClass):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").setClassResource(self, classResource)

func setSprite(classResource, _chibi: bool):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").setSprite(self, classResource, _chibi)

func pve_apply_role_stats():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").pve_apply_role_stats(self)

func pve_set_combat_anchor():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").pve_set_combat_anchor(self)

func pve_reset_presentation(scene_name: String):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").pve_reset_presentation(self, scene_name)

func titleToShop():
	animation.play("EnterShopFromTitle")
	playSound(Game.classResources[characterClass].getRunStartSound())
	randomClassParticles.deactivate()

func shopEntered():
	opponent = null

func shopToCombat():
	animation.advance(100)
	animation.play("RESET")
	animation.advance(100)
	animation.play("EnterCombatFromShop")

func combatToShop():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").combatToShop(self)

func combatToTitle():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").combatToTitle(self)

func shopToTitle():
	animation.play("StartOnTitle")

func finishAnimations():
	animation.advance(100)
	call_deferred("finishAnimations_deferred")

func finishAnimations_deferred():
	invuBubbleAni.advance(100)
	battleRageAnimation.advance(100)
	battleRageParticles.restart()
	battleRageParticles.emitting = false

func playSound(stream, volume = 0, pitch = 1.0, force = false):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").playSound(self, stream, volume, pitch, force)

func prepare():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").prepare(self)

func combatStart():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").combatStart(self)

func combatEnd():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").combatEnd(self)

func cleanse():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").cleanse(self)

func onTick():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").onTick(self)

func replayEvent(event):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").replayEvent(self, event)

const attackForwardSpeed = 2600.0
const attackBackwardSpeed = 1000.0
const jumpSpeed = 300.0
const activateJumpHeight = 40.0

const attackSounds = [
	preload("res://Assets/Sound/Swing1.wav"),
	preload("res://Assets/Sound/Swing2.wav"),
	preload("res://Assets/Sound/Swing3.wav")
]

const invuSound = preload("res://Assets/Sound/Invu.wav")
const stunnedSound = preload("res://Assets/Sound/Stun.ogg")

func playAttackAnimation(distance = Util.rng.randf_range(100, 160)):
	if sprite.has_method("attack"): sprite.attack()
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").playAttackAnimation(self, distance)

func attackMovingBack():
	attackMovingForward = false

func playActivateAnimation():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").playActivateAnimation(self)

func dealDamage(damageSource: DamageSource, triggerEvent = null) -> DamageResult:

	playAttackAnimation()
	var res = opponent.takeDamage(damageSource, triggerEvent)
	applyVampirism(res)
	return res

func getName():
	return ["Player", "Opponent"][playerId]

func getCenter():
	return global_position - Vector2(0, 100)

func takeDamage(damageSource: DamageSource, triggerEvent = null) -> DamageResult:
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").takeDamage(self, damageSource, triggerEvent)

func isVulnerable():
	return not invulnerable

const DMG_NUM_OFFSET = Vector2(50, 70)
const DMG_NUM_CENTER = [Vector2( - 100, - 40), Vector2(100, - 40)]
const HEAL_NUM_CENTER = [Vector2(0, - 40), Vector2(0, - 40)]

const BUFFLABEL_CENTER = [Vector2( - 100, 100), Vector2(100, 100)]
const BUFFLABEL_OFFSET = Vector2(60, 40)

func randDmgNumberPos():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").randDmgNumberPos(self)

func randHealNumberPos():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").randHealNumberPos(self)

const dmgNumBaseDir= Vector2(0, - 660)
const dmgNumMinAngle= deg_to_rad( - 21)
const dmgNumMaxAngle= deg_to_rad( - 3)

func randDmgNumberDir():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").randDmgNumberDir(self)

func randBuffLabelPos():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").randBuffLabelPos(self)

func spawnLabel(type: int, damage: int, item = null,
	pos: Vector2 = randDmgNumberPos(),
	direction: Vector2 = randDmgNumberDir()):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").spawnLabel(self, type, damage, item, pos, direction)

func applySpikes(damageRes: DamageResult):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").applySpikes(self, damageRes)

func applyVampirism(damageRes: DamageResult):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").applyVampirism(self, damageRes)

func heal(amount, origin = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").heal(self, amount, origin, triggerEvent)

func healToFull():
	curHealth = getMaxHealth()
	emit_signal("health_changed_ui")

func reincarnate(healAmount: int, isHeal: bool, item, triggerEvent):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").reincarnate(self, healAmount, isHeal, item, triggerEvent)

func getMaxStamina():
	return maxStamina + temporaryMaxStamina

func gainStamina(amount, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").gainStamina(self, amount, item, triggerEvent)

func addStamina(amount):
	curStamina += amount
	clampStamina()

func clampStamina():
	curStamina = clamp(curStamina, 0, getMaxStamina())

func fillUpStamina():
	addStamina(maxStamina)

enum StaminaResult{
	Sufficient = 0,
	Insufficient = 1,
}

func useStamina(amount):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").useStamina(self, amount)

func drainStamina(amount, item, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").drainStamina(self, amount, item, triggerEvent)

func setCurrentHealth(_curHealth):
	curHealth = _curHealth
	emit_signal("health_changed_ui")

func loseHealth(amount, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").loseHealth(self, amount, item, triggerEvent)

func setMaxHealth(_maxHealth):
	maxHealth = _maxHealth
	curHealth = maxHealth
	emit_signal("health_changed_ui")

func giveMaxHealth(amount):
	maxHealth += amount
	curHealth += amount
	emit_signal("health_changed_ui")

func getBaseMaxHealth():
	return maxHealth

func getMaxHealth():
	return maxHealth + temporaryMaxHealth

func applyTemporaryMaxHealthGain(amount):
	return round(amount * temporaryMaxHealthGain)

func changeMaxHealthTemporary(amount, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").changeMaxHealthTemporary(self, amount, item, triggerEvent)

func changeMaxHealthGain(amount):
	temporaryMaxHealthGain += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.MaxHealthGain, true)

func getTemporaryMaxHealth():
	return temporaryMaxHealth

func setTemporaryMaxHealth(tempHealth):
	temporaryMaxHealth = tempHealth
	emit_signal("health_changed_ui")

func getCurrentHealth():
	return curHealth

func getRelativeHealth() -> float:
	return getCurrentHealth() / getMaxHealth()

func getMissingHealth() -> int:
	return int(ceil(getMaxHealth() - getCurrentHealth()))

func reduceMaxHealth(amount):
	maxHealth = max(1, maxHealth - amount)
	curHealth = min(maxHealth, curHealth)
	emit_signal("health_changed_ui")

func getCurrentStamina() -> float:
	return curStamina

func setCurrentStamina(stamina: float):
	curStamina = stamina

func getBaseMaxStamina() -> float:
	return baseMaxStamina

func getMaxBaseStamina() -> float:
	return maxStamina

func getMissingStamina() -> float:
	return getMaxStamina() - getCurrentStamina()

func isFullStamina() -> bool:
	return getMissingStamina() <= 0

func setMaxStamina(_maxStamina):
	maxStamina = _maxStamina
	curStamina = maxStamina
	emit_signal("max_stamina_changed_ui")

func giveMaxStamina(amount):
	maxStamina += amount
	curStamina += amount
	emit_signal("max_stamina_changed_ui")

func reduceMaxStamina(amount):
	maxStamina = max(1, maxStamina - amount)
	curStamina = min(maxStamina, curStamina)
	emit_signal("max_stamina_changed_ui")

func changeBaseMaxStamina():
	if playerId == ID.PLAYER and not staminaUpdateQueued:
		staminaUpdateQueued = true
		call_deferred("recalculateMaxStamina")

var staminaUpdateQueued = false

func recalculateMaxStamina():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").recalculateMaxStamina(self)

func gainMaxStaminaTemporary(amount, item, triggerEvent, filled: bool = true):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").gainMaxStaminaTemporary(self, amount, item, triggerEvent, filled)

func setTemporaryMaxStamina(amount):
	temporaryMaxStamina = amount
	emit_signal("max_stamina_changed_ui")

func death():
	isDead = true
	emit_signal("character_died")

func lose():
	loseParticles.activate()
	damageAnimation.play("Lose")

func win():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").win(self)

func levelUp():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").levelUp(self)

func _physics_process(delta: float) -> void :
	if stunnedDuration > 0:
		stunnedDuration -= delta
		if stunnedDuration <= 0:
			endStun()

	addStamina(getStaminaRegeneration() * delta)

func makeInvulnerable(invuDur, item, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").makeInvulnerable(self, invuDur, item, triggerEvent)

func makeVulnerable(item, triggerEvent = null):
	pass

func invulnerabilityEnded():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").invulnerabilityEnded(self)

func playInvulnerableAnimation(invu):
	if invu:
		invuBubbleAni.play("Invulnerable")
		invulBubbleVisible = true
	else:
		invuBubbleAni.play("Vulnerable")
		invulBubbleVisible = false

func stun(duration, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").stun(self, duration, item, triggerEvent)

func endStun():
	stunnedDuration = 0.0
	Game.combatLog.snapshotCharacterStat(self, Stat.Stunned, true)
	playStunAnimation()

func playStunAnimation(duration = stunnedDuration):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").playStunAnimation(self, duration)

func isStunned():
	return stunnedDuration > 0

func getStaminaRegeneration():
	return staminaRegen

func giveStaminaRegeneration(amount):
	staminaRegen += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.StaminaRegen)

func getTotalStaminaUsage():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").getTotalStaminaUsage(self)

func getStacks(buffType) -> int:
	return buffs[buffType].getStacks()

func getBuffStacks() -> int:
	var stacks = 0
	for buff in Game.getBuffs():
		stacks += getStacks(buff)
	return stacks

func getDebuffStacks() -> int:
	var stacks = 0
	for debuff in Game.getDebuffs():
		stacks += getStacks(debuff)

	return stacks

func setStacks(buffType, amount: int):
	buffs[buffType].setStacks(amount)

func setStacksLogged(buffType, amount: int, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").setStacksLogged(self, buffType, amount, item, triggerEvent)

func gainStacks(buffType, amount: int, item = null, triggerEvent = null,
	reflect: bool = false):

	return buffs[buffType].gainStacks(amount, item, triggerEvent)

func gainStacksTemporary(buffType, amount: int, duration, item = null,
	triggerEvent = null, reflect: bool = false):

	return buffs[buffType].gainTemporary(amount, duration, item, triggerEvent, reflect)

func loseStacks(buffType, amount: int, item = null, triggerEvent = null):
	return buffs[buffType].loseStacks(amount, item, triggerEvent)

func useStacks(buffType, amount: int, item = null, triggerEvent = null):
	return buffs[buffType].loseStacks(amount, item, triggerEvent, true)

func changeResistChance(buffType, chance):
	buffs[buffType].changeResistChance(chance)

func changeDebuffResistChances(chance):
	for debuff in Game.getDebuffs():
		changeResistChance(debuff, chance)

func changeBuffNullifyChances(chance):
	for buff in Game.getBuffs():
		changeResistChance(buff, chance)

func getBlock():
	return getStacks(Game.EventType.Block)

func setBlock(amount: int):
	setStacks(Game.EventType.Block, amount)

func gainBlock(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Block, amount, item, triggerEvent)

func loseBlock(amount, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Block, amount, item, triggerEvent)

func getSpikes():
	return getStacks(Game.EventType.Spikes)

func setSpikes(amount: int):
	setStacks(Game.EventType.Spikes, amount)

func gainSpikes(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Spikes, amount, item, triggerEvent)

func loseSpikes(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Spikes, amount, item, triggerEvent)

func getVampirism():
	return getStacks(Game.EventType.Vampirism)

func setVampirism(amount: int):
	setStacks(Game.EventType.Vampirism, amount)

func gainVampirism(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Vampirism, amount, item, triggerEvent)

func loseVampirism(amount, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Vampirism, amount, item, triggerEvent)

func getPoison():
	return getStacks(Game.EventType.Poison)

func setPoison(amount: int):
	setStacks(Game.EventType.Poison, amount)

func gainPoison(amount: int, item = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").gainPoison(self, amount, item, triggerEvent)

func losePoison(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Poison, amount, item, triggerEvent)

func changePoisonCritChancePercent(amount):
	poisonDamageSource.addCritChancePercent(amount)

func changeSpikesCritChancePercent(amount):
	spikeDamageSource.addCritChancePercent(amount)

func getRegeneration():
	return getStacks(Game.EventType.Regeneration)

func setRegeneration(amount: int):
	setStacks(Game.EventType.Regeneration, amount)

func gainRegeneration(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Regeneration, amount, item, triggerEvent)

func loseRegeneration(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Regeneration, amount, item, triggerEvent)

func getLucky():
	return getStacks(Game.EventType.Lucky)

func setLucky(amount: int):
	setStacks(Game.EventType.Lucky, amount)

func gainLucky(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Lucky, amount, item, triggerEvent)

func loseLucky(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Lucky, amount, item, triggerEvent)

func getBlind():
	return getStacks(Game.EventType.Blind)

func setBlind(amount: int):
	setStacks(Game.EventType.Blind, amount)

func gainBlind(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Blind, amount, item, triggerEvent)

func loseBlind(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Blind, amount, item, triggerEvent)

func getMana():
	return getStacks(Game.EventType.Mana)

func setMana(amount: int):
	setStacks(Game.EventType.Mana, amount)

func gainMana(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Mana, amount, item, triggerEvent)

func useMana(amount: int, item = null, triggerEvent = null):
	var event = useStacks(Game.EventType.Mana, amount, item, triggerEvent)

	return event

func loseMana(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Mana, amount, item, triggerEvent)

func getEmpower():
	return getStacks(Game.EventType.Empower)

func setEmpower(amount: int):
	setStacks(Game.EventType.Empower, amount)

func gainEmpower(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Empower, amount, item, triggerEvent)

func loseEmpower(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Empower, amount, item, triggerEvent)

func getHeat():
	return getStacks(Game.EventType.Heat)

func setHeat(amount: int):
	setStacks(Game.EventType.Heat, amount)

func gainHeat(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Heat, amount, item, triggerEvent)

func loseHeat(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Heat, amount, item, triggerEvent)

func getCold():
	return getStacks(Game.EventType.Cold)

func setCold(amount: int):
	setStacks(Game.EventType.Cold, amount)

func gainCold(amount: int, item = null, triggerEvent = null):
	return gainStacks(Game.EventType.Cold, amount, item, triggerEvent)

func loseCold(amount: int, item = null, triggerEvent = null):
	return loseStacks(Game.EventType.Cold, amount, item, triggerEvent)

func getBuffDamageMod():
	return getEmpower() * empowerDamage

func getBuffAccuracyMod():
	return (getLucky() - getBlind()) * 5

func changeDamageResistance(amount: float, item = null, duration = null,
	triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").changeDamageResistance(self, amount, item, duration, triggerEvent)

func changeDamageReduction(amount: int):
	damageReduction += amount

func changeDodgeStacks(amount: int):
	dodgeStacks = int(max(0, dodgeStacks + amount))
	Game.combatLog.snapshotCharacterStat(self, Stat.DodgeStacks)

func changeCritResistance(amount: float):
	critResistance += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.CritResistance, true)

func critResisted() -> bool:
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").critResisted(self)

func gainCritResistStacks(num: int):
	critResistStacks += num
	Game.combatLog.snapshotCharacterStat(self, Stat.CritResistStacks, true)

func changeStunResistance(amount: float):
	stunResistance += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.StunResistance, true)

func stunResisted() -> bool:
	return stunResistanceRng.rollPercent(stunResistance)

func giveUnhealing(amount: float):
	unhealingAmount += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.Unhealing)

func reduceUnhealing(amount: float):
	unhealingAmount = max(0.0, unhealingAmount - amount)
	Game.combatLog.snapshotCharacterStat(self, Stat.Unhealing)

func getUnhealing():
	return unhealingAmount

func getHealingEfficiency():
	return max(0.0, healingEfficiency)

func addHealingEfficiency(amount: float):
	healingEfficiency += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.HealEfficiency)

func reduceHealingEfficiency(amount: float):
	healingEfficiency -= amount
	Game.combatLog.snapshotCharacterStat(self, Stat.HealEfficiency)

func getCritTokens():
	return critTokens

func gainCritTokens(amount):
	critTokens += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.CritStacks)

func useCritToken():
	critTokens -= 1
	Game.combatLog.snapshotCharacterStat(self, Stat.CritStacks)

func changeResistStacks(buffType, amount):
	buffs[buffType].changeResistStacks(amount)

func changeDebuffProtectionChance(chance):
	for debuff in Game.getDebuffs():
		buffs[debuff].changeCleanseProtectionChance(chance)

func changeProtectionChance(buffType, chance):
	buffs[buffType].changeCleanseProtectionChance(chance)

func changeBuffProtectionChance(chance):
	for buff in Game.getBuffs():
		buffs[buff].changeCleanseProtectionChance(chance)

func changeDebuffResistStacks(amount):
	debuffResistStacks += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.DebuffResistStacks, true)

func changeDebuffReflectStacks(amount):
	debuffReflectStacks += amount
	Game.combatLog.snapshotCharacterStat(self, Stat.ReflectStacks, true)

func changeBuffProtectStacks(amount):
	buffProtectStacks += amount

func changeReflectChance(debuff, amount):
	buffs[debuff].changeReflectChance(amount)

func changeAllDebuffsReflectChance(amount):
	for debuff in Game.getDebuffs():
		changeReflectChance(debuff, amount)

func changeMeleeSpikesLimit(amount):
	meleeSpikesLimit += amount

func changeRangedSpikesLimit(amount):
	rangedSpikesLimit += amount

func changeEffectSpikesLimit(amount):
	effectSpikesLimit += amount

func changeMeleeVampirismLimit(amount):
	meleeVampirismLimit += amount

func changeRangedVampirismLimit(amount):
	rangedVampirismLimit += amount

func changeEmpowerDamage(amount):
	empowerDamage += amount

func changeTypedDamageFactor(damageType: int, amount):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").changeTypedDamageFactor(self, damageType, amount)

func changeEffectDamageFactor(amount):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").changeEffectDamageFactor(self, amount)

func getGoldPos():
	return goldPos.global_position

func _onNameChanged(new_text: String) -> void :
	Game.setPlayerName(new_text)
	nameLabel.text = Game.getPlayerName()

func onSpriteClicked():
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").onSpriteClicked(self)

func disableClicking():
	clickArea.mouse_filter = Control.MOUSE_FILTER_IGNORE

func enableClicking():
	clickArea.mouse_filter = Control.MOUSE_FILTER_STOP

func randAnimationSpeed() -> void :
	load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").randAnimationSpeed(self)

func isBattleRaging():
	return not battleRageTimer.is_stopped()

func startBattleRage(item, duration, triggerEvent = null, applyBonus = true):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").startBattleRage(self, item, duration, triggerEvent, applyBonus)

func endBattleRage():
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").endBattleRage(self)

func playBattleRageAnimation(rageStart):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").playBattleRageAnimation(self, rageStart)

func addBattleRageDuration(dur):
	battleRageBonusDur += dur

func startAutoRage():
	startBattleRage(autoRageItem, AUTO_RAGE_DUR)

func getBonusFatigueDamage():
	return bonusFatigueDamage

func addFatigueDamage(amount):
	bonusFatigueDamage += amount
	EventBus.emitSignal(self, "fatigue_damage_changed")

func takeFatigueDamage(item = null):

	takeDamage(Game.fatigueDamageSource)

func startBlindingLight():
	blindingLightActive = true

func endBlindingLight(event = null):
	blindingLightActive = false
	EventBus.emitSignal(self, "blinding_light_ended", [event])

func setStat(stat, value):
	return load("res://Runtime/Behavior/Features/Core/CharacterBehavior.gd").setStat(self, stat, value)

func getStat(stat):
	return load("res://Runtime/Behavior/Core/CharacterBehavior.gd").getStat(self, stat)

func queue_free():
	Util.removeLocalizedNode(nameLabel)
	super.queue_free()
