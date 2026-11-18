extends RefCounted
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const KEYS = ["title","title_logo","select_armorer","select_archer","select_alchemist","title_book","button","button_blue","button_red","settings"]

static func saved_run() -> Dictionary:
	var saved = Expedition.flow.saves.load_save("run")
	if not saved.ok or not Expedition.flow.saves.validate_run(saved.get("data",{}),Expedition.db).ok: return {}
	if saved.data.get("last_safe_state",saved.data.get("state","")) == "RUN_RESULT": return {}
	return saved.data

static func build(root: Control):
	REF.picture(root,"title",Rect2(0,0,1920,1080),true)
	REF.picture(root,"title_logo",Rect2(603,310,714,211))
	REF.button(root,"settings",Rect2(1822,14,59,59),Expedition.show_settings).name = "TitleSettings"
	REF.button(root,"title_book",Rect2(1342,831,383,250),Expedition.show_codex).name = "TitleCodex"
	var saved = saved_run()
	if not saved.is_empty():
		REF.picture(root,"select_"+str(saved.character_id),Rect2(235,578,463,504))
	var begin = REF.button(root,"button",Rect2(786,595,348,79),func():
		if not saved_run().is_empty(): Expedition.continue_run()
		else: Expedition.menus.runs.new_setup(),Expedition.bilingual("继续游戏" if not saved.is_empty() else "开始游戏","Continue" if not saved.is_empty() else "Start game"),48)
	begin.name = "TitleStart"
	REF.button(root,"button_blue",Rect2(786,691,348,79),Game.quit,Expedition.bilingual("退出游戏","Exit game"),48).name = "TitleExit"
	if not saved.is_empty():
		REF.button(root,"button_red",Rect2(751,785,418,79),Expedition.menus.runs.new_setup,Expedition.bilingual("结束当前对决","New expedition"),48).name = "TitleNewRun"
