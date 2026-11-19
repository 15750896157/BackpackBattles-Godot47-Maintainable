extends RefCounted
## The carousel changes a draft only. Begin is the existing new_run transaction.
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
var runs:
	get: return owner.menus.runs
var owner
var ui
var draft_index = 0
const KEYS = ["selection","selection_shadow","select_armorer","select_archer","select_alchemist","previous","next","back","button","settings"]
## 可选角色清单由数据驱动（release_catalog.selectable_characters），新增角色不再改代码。
func roles() -> Array:
	return owner.db.release_catalog.get("selectable_characters", ["armorer"])
func _init(page):
	owner = page.owner; ui = page.ui
func show_page():
	if runs.role not in roles():runs.role=roles()[0]
	var root = ui.open_canvas("SETUP",ui.words("选择角色","Choose a hero"))
	var ticket = owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(KEYS),"popup") or ticket != owner.popup_epoch: return
	REF.picture(root,"selection",Rect2(0,0,1920,1080),true)
	REF.picture(root,"selection_shadow",Rect2(672,886,537,131))
	var rect = Rect2(642,330,584,634) if runs.role == "armorer" else Rect2(670,330,580,634)
	REF.picture(root,"select_"+runs.role,rect)
	var data = owner.db.get_row("characters",runs.role)
	REF.text(root,owner.t(data.name_key),Rect2(229,307,185,58),44,Color("ffca58"))
	var description = ui.words("攻守兼备\n近战武器特化\n搭配近战和护甲","Attack and defense\nMelee specialist\nWeapons and armor") if runs.role == "armorer" else ui.words("精准与连射\n暴击和灼烧节奏\n搭配弓箭和饰品","Precision and speed\nCritical and burn rhythm\nBows and trinkets")
	if runs.role == "alchemist":description=ui.words("药剂与反应\n毒素和灼烧特化\n搭配药剂和恢复","Potions and reactions\nPoison and burn rhythm\nAlchemy and recovery")
	REF.text(root,description,Rect2(224,389,202,137),25,Color("f8bd4a"))
	REF.button(root,"previous",Rect2(520,939,120,92),func(): turn_role(-1)).name = "RolePrevious"
	REF.button(root,"next",Rect2(1241,939,120,92),func(): turn_role(1)).name = "RoleNext"
	REF.button(root,"back",Rect2(49,952,117,86),owner.view_return).name = "SelectionBack"
	REF.button(root,"settings",Rect2(1822,14,59,59),owner.show_settings).name = "SelectionSettings"
	REF.button(root,"button",Rect2(767,952,348,79),begin,ui.words("开始冒险","Begin adventure"),48).name = "BeginExpedition"
	# Preserve both starting loadouts and every unlocked difficulty without menus.
	# Touching either line cycles its value in place; the banner remains readable.
	var loadouts = owner.db.starting_loadouts(runs.role)
	if not loadouts.any(func(row):return row.id == runs.loadout): runs.loadout = loadouts[0].id
	var chosen = owner.db.get_row("character_loadouts",runs.loadout)
	REF.text(root,owner.t(chosen.name_key)+"  ›",Rect2(221,537,205,36),21,Color("f6ca7e"))
	REF.zone(root,Rect2(218,527,212,57),func():
		var index = loadouts.find(chosen); runs.loadout = loadouts[(index+1)%loadouts.size()].id; show_page(),ui.words("切换初始装备","Change starting gear")).name = "ChooseLoadout"
	var levels = owner.db.rows("difficulty_levels").filter(func(row):return row.id in owner.flow.profile_service.profile.unlocks)
	REF.text(root,owner.t("difficulty."+runs.difficulty+".name")+"  ›",Rect2(221,582,205,36),21,Color("f6ca7e"))
	REF.zone(root,Rect2(218,577,212,52),func():
		var ids = levels.map(func(row):return row.id); runs.difficulty = ids[(ids.find(runs.difficulty)+1)%ids.size()]; show_page(),ui.words("切换难度","Change difficulty")).name = "ChooseDifficulty"
	REF.fade_in(root)
func turn_role(direction: int):
	var list = roles()
	runs.role = list[posmod(list.find(runs.role)+direction,list.size())]
	runs.loadout = ""; show_page()
func begin():
	if runs.seed_value == 0: runs.seed_value = Time.get_ticks_usec() & 0xffffffff
	if owner.native_routes != null:
		owner.create_run(runs.role, runs.loadout, runs.difficulty, runs.seed_value, true)
		return
	var ticket=await owner.art.curtain.cover("new_expedition")
	var result=owner.create_run(runs.role,runs.loadout,runs.difficulty,runs.seed_value,true)
	if not result.ok:
		await owner.art.curtain.reveal(ticket)
		return
	await owner.get_tree().process_frame
	owner.art.reveal_ready("title",ticket,owner.view_epoch)
