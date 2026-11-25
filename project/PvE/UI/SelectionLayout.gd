extends RefCounted
## The carousel changes a draft only. Begin is the existing new_run transaction.
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
var runs:
	get: return owner.menus.runs
var owner
var ui
var draft_index = 0
const KEYS = ["selection","selection_shadow","select_armorer","select_archer","select_alchemist","previous","next","back","button","settings"]
## Live role nodes. The background, shadow and buttons are built once; only
## these swap, so switching a hero never tears the page down or reloads art.
var role_art: TextureRect
var role_name: Label
var role_desc: Label
var loadout_text: Label
var difficulty_text: Label
## 可选角色清单由数据驱动（release_catalog.selectable_characters），新增角色不再改代码。
func roles() -> Array:
	return owner.db.release_catalog.get("selectable_characters", ["armorer"])
func _init(page):
	owner = page.owner; ui = page.ui
## Each portrait keeps its own aspect, so the frame is lowered where the art is
## wider: the drawn feet must land on the same rug line (y ~ 964) for every hero.
func role_rect() -> Rect2:
	if runs.role == "armorer": return Rect2(642,330,584,634)
	if runs.role == "alchemist": return Rect2(670,370,580,634)
	return Rect2(670,330,580,634)
func role_name_text() -> String:
	return owner.t(owner.db.get_row("characters",runs.role).name_key)
func role_description() -> String:
	if runs.role == "alchemist":return ui.words("药剂与反应\n毒素和灼烧特化\n搭配药剂和恢复","Potions and reactions\nPoison and burn rhythm\nAlchemy and recovery")
	if runs.role == "armorer":return ui.words("攻守兼备\n近战武器特化\n搭配近战和护甲","Attack and defense\nMelee specialist\nWeapons and armor")
	return ui.words("精准与连射\n暴击和灼烧节奏\n搭配弓箭和饰品","Precision and speed\nCritical and burn rhythm\nBows and trinkets")
func unlocked_levels() -> Array:
	return owner.db.rows("difficulty_levels").filter(func(row):return row.id in owner.flow.profile_service.profile.unlocks)
func show_page():
	if runs.role not in roles():runs.role=roles()[0]
	var root = ui.open_canvas("SETUP",ui.words("选择角色","Choose a hero"))
	var ticket = owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(KEYS),"popup") or ticket != owner.popup_epoch: return
	REF.picture(root,"selection",Rect2(0,0,1920,1080),true)
	REF.picture(root,"selection_shadow",Rect2(672,886,537,131))
	role_art = REF.picture(root,"select_"+runs.role,role_rect())
	role_name = REF.text(root,"",Rect2(229,307,185,58),44,Color("ffca58"))
	role_desc = REF.text(root,"",Rect2(224,389,202,137),25,Color("f8bd4a"))
	REF.button(root,"previous",Rect2(520,939,120,92),func(): turn_role(-1)).name = "RolePrevious"
	REF.button(root,"next",Rect2(1241,939,120,92),func(): turn_role(1)).name = "RoleNext"
	REF.button(root,"back",Rect2(49,952,117,86),owner.view_return).name = "SelectionBack"
	REF.button(root,"settings",Rect2(1822,14,59,59),owner.show_settings).name = "SelectionSettings"
	REF.button(root,"button",Rect2(767,952,348,79),begin,ui.words("开始冒险","Begin adventure"),48).name = "BeginExpedition"
	# Preserve both starting loadouts and every unlocked difficulty without menus.
	# Touching either line cycles its value in place; the banner remains readable.
	loadout_text = REF.text(root,"",Rect2(221,537,205,36),21,Color("f6ca7e"))
	REF.zone(root,Rect2(218,527,212,57),cycle_loadout,ui.words("切换初始装备","Change starting gear")).name = "ChooseLoadout"
	difficulty_text = REF.text(root,"",Rect2(221,582,205,36),21,Color("f6ca7e"))
	REF.zone(root,Rect2(218,577,212,52),cycle_difficulty,ui.words("切换难度","Change difficulty")).name = "ChooseDifficulty"
	refresh_role()
	REF.fade_in(root)
func turn_role(direction: int):
	var list = roles()
	runs.role = list[posmod(list.find(runs.role)+direction,list.size())]
	runs.loadout = ""
	refresh_role()
func cycle_loadout():
	var loadouts = owner.db.starting_loadouts(runs.role)
	var index = loadouts.find(owner.db.get_row("character_loadouts",runs.loadout))
	runs.loadout = loadouts[(index+1)%loadouts.size()].id
	refresh_plate()
func cycle_difficulty():
	var ids = unlocked_levels().map(func(row):return row.id)
	runs.difficulty = ids[(ids.find(runs.difficulty)+1)%ids.size()]
	refresh_plate()
## In-place refresh: only the hero art and the plate text change.
func refresh_role():
	var loadouts = owner.db.starting_loadouts(runs.role)
	if not loadouts.any(func(row):return row.id == runs.loadout): runs.loadout = loadouts[0].id
	if is_instance_valid(role_art):
		var rect = role_rect()
		role_art.name = "Ref_select_"+runs.role
		role_art.texture = REF.texture("select_"+runs.role)
		role_art.position = rect.position; role_art.size = rect.size
		role_art.set_meta("reference_rect",rect)
	rebind(role_name,role_name_text(),44,Color("ffca58"))
	rebind(role_desc,role_description(),25,Color("f8bd4a"))
	refresh_plate()
func refresh_plate():
	var chosen = owner.db.get_row("character_loadouts",runs.loadout)
	rebind(loadout_text,owner.t(chosen.name_key)+"  ›",21,Color("f6ca7e"))
	rebind(difficulty_text,owner.t("difficulty."+runs.difficulty+".name")+"  ›",21,Color("f6ca7e"))
func rebind(label: Label, value: String, size: int, color: Color):
	if not is_instance_valid(label): return
	REF.bind_text(label,value,label.size,size,color,0)
	REF.center_label(label)
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
