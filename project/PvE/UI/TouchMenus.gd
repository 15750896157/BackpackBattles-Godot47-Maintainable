extends RefCounted
## Public page router; page implementations contain no window creation.
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
func prepare_icons():
	var paths:Array=[]
	for key in ["battle","guide","codex","journey","settings","home","window","button","card","close","previous","next","continue","new_run","hand","button_blue","button_red"]:
		var supplied=preload("res://PvE/Art/SuppliedArt.gd").ui_path(key) if key in ["battle","codex","journey","settings","button","hand","button_blue","button_red"] else ""
		paths.append(supplied if not supplied.is_empty() else (shell.TOUCH_ART if key in ["window","button","card","close","previous","next","continue","new_run"] else shell.ART)+key+".png")
	await AssetStream.prepare(paths,"mobile-ui-icons")
	await AssetStream.prepare(["res://Art/Supplied20261028/ui/selection.png",preload("res://PvE/Art/SuppliedArt.gd").actor_path("armorer"),preload("res://PvE/Art/SuppliedArt.gd").actor_path("alchemist")],"role-ui")
