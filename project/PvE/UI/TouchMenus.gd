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
	for key in ["battle","guide","codex","journey","settings","home"]:paths.append(shell.ART+key+".png")
	for key in ["window","button","card","close","previous","next","continue","new_run"]:paths.append(shell.TOUCH_ART+key+".png")
	await AssetStream.prepare(paths,"mobile-ui-icons")
