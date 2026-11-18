extends RefCounted
const REF=preload("res://PvE/UI/ReferenceCanvas.gd")
static func show_page(page):
	var owner=page.owner;var ui=page.ui
	var root=ui.open_canvas("REST",owner.t("ui.rest"));var ticket=owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(["camp","window","route_coin","camp_heart","route_header_chip","camp_back","settings"]),"popup") or ticket!=owner.popup_epoch:return
	REF.picture(root,"camp",Rect2(0,0,1920,1080),true).name="RestCampArt"
	preload("res://PvE/UI/RouteLayout.gd").header(root,owner,"camp_back",false)
	REF.text(root,owner.bilingual("营地休整","Camp"),Rect2(710,113,500,70),42,Color("ffdf9f"),2)
	var panels:Array=[]
	for left in [145,1240]:
		var panel=REF.picture(root,"window",Rect2(left,230,535,360),true);panel.modulate.a=0.95;panel.name="RestChoicePanel_"+str(panels.size());panels.append(panel)
	var choices=ui.grid(root,2);choices.position=Vector2(175,265);choices.size=Vector2(1570,290);choices.add_theme_constant_override("h_separation",650)
	page.populate_choices(choices,true,460)
	# Localized text and the user's text-size preference can grow the options.
	# Fit the parchment to the measured container, keeping every action inside.
	await owner.get_tree().process_frame
	if ticket!=owner.popup_epoch or not is_instance_valid(root):return
	for panel in panels:panel.size.y=maxf(360,choices.get_combined_minimum_size().y+70)
	owner.focus_popup()
