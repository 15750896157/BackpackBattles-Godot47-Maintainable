extends RefCounted
## Public page router; page implementations contain no window creation.
const SHOP_MODEL = preload("res://Runtime/ViewModel/ShopVM.gd")
var owner
var shell
var runs
var library
var journey
var settings
var guide
func _init(host):
	owner=host;shell=preload("res://PvE/UI/MenuShell.gd").new(host)
	runs=preload("res://PvE/UI/RunPages.gd").new(host,shell)
	library=preload("res://PvE/UI/LibraryPage.gd").new(host,shell)
	journey=preload("res://PvE/UI/JourneyPage.gd").new(host,shell)
	settings=preload("res://PvE/UI/SettingsPage.gd").new(host,shell)
	guide=preload("res://PvE/UI/GuidePage.gd").new(host,shell)

func new_journey_model() -> SHOP_MODEL:
	return SHOP_MODEL.new(owner.flow,func(): return {},_dispatch_journey)

func _dispatch_journey(action: StringName, args: Array) -> Dictionary:
	var result: Dictionary
	match action:
		&"choose_route":
			var pending := bool(owner.flow.run.get("route_pending",false))
			result = owner.flow.choose_route(int(args[0]))
			# Picking a fight from a prepared shop keeps the same flow state,
			# so the screen-state renderer does not dismiss this popup.
			if pending and owner.flow.screen_state == "SHOP_PREPARE" and not owner.flow.run.get("route_pending",false):
				owner.close_popup()
		&"choose_event_action": result = owner.flow.event_choice(str(args[0]),args[1])
		_: return {"ok":false,"error":"unknown_action"}
	owner.perform(result)
	return result
func prepare_icons():
	await AssetStream.prepare(preload("res://PvE/UI/ReferenceCanvas.gd").paths(["window","button","button_blue","button_red","close","previous","next","back","settings","codex","journey","battle","hand"]),"reference-common")
	var paths:Array=[]
	for key in ["guide","home","card","continue","new_run"]:
		if key in ["guide","home"]:
			paths.append(preload("res://PvE/UI/ReferenceCanvas.gd").path(key));continue
		var supplied=preload("res://PvE/Art/SuppliedArt.gd").ui_path(key) if key in ["battle","codex","journey","settings","button","hand","button_blue","button_red"] else ""
		paths.append(supplied if not supplied.is_empty() else (shell.TOUCH_ART if key in ["window","button","card","close","previous","next","continue","new_run"] else shell.ART)+key+".png")
	await AssetStream.prepare(paths,"mobile-ui-icons")
