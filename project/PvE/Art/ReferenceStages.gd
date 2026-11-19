extends RefCounted
## Placement comes from the supplied shop PSD and battle composition.
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const SHOP_SCALE = Vector2(1920.0/1942.0,1080.0/1123.0)
static func shop_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position*SHOP_SCALE,rect.size*SHOP_SCALE)
static func shop(art):
	art.picture("shelf",shop_rect(Rect2(-248,232,1022,78)),art.scenery)
	art.picture("shelf",shop_rect(Rect2(-72,562,1022,78)),art.scenery)
	art.picture("merchant",shop_rect(Rect2(-4,596,487,320)),art.scenery)
	art.picture("table",shop_rect(Rect2(0,902,1942,235)),art.scenery)
	art.picture("storage_mat",shop_rect(Rect2(456,893,1165,266)),art.scenery).name="StorageCloth"
	art.picture("sell",shop_rect(Rect2(162,886,302,237)),art.scenery)
	art.button("codex",shop_rect(Rect2(463,807,243,119)),art.open_book)
	art.button("refresh",shop_rect(Rect2(799,-97,122,322)),art._refresh_shop)
	REF.picture(art.ui,"coin",shop_rect(Rect2(819,88,27,27)))
	art.text("",shop_rect(Rect2(846,86,35,36)),art.ui,29,Color("fff4d1")).name = "RefreshCost"
	art.picture("battle",shop_rect(Rect2(1693,-312,234,755)),art.ui)
	var start = REF.zone(art.ui,shop_rect(Rect2(1693,267,234,176)),art._start)
	start.name = "ArtStartBattle"
	art.text("开战",Rect2(Vector2(22,38)*SHOP_SCALE,Vector2(191,52)*SHOP_SCALE),start,36).name = "StageCaption"
	art.text("",Rect2(Vector2(24,96)*SHOP_SCALE,Vector2(184,42)*SHOP_SCALE),start,27,Color("e7b77b")).name = "StageNumber"
	art.button("settings",shop_rect(Rect2(1843,15,58,59)),Expedition.show_settings).name = "Action_shop_settings"
	art.picture("plate1",shop_rect(Rect2(1558,38,126,40)),art.ui)
	REF.picture(art.ui,"coin",shop_rect(Rect2(1558,36,39,39)))
	art.text("",shop_rect(Rect2(1604,35,80,42)),art.ui,26).name = "GoldValue"
	var tag_positions = [Vector2(240,178),Vector2(532,178),Vector2(175,503),Vector2(466,503),Vector2(728,503)]
	for index in 5:
		var tag = art.button("price",shop_rect(Rect2(tag_positions[index],Vector2(90,59))),art._lock.bind(index))
		REF.picture(tag,"coin",Rect2(7,26,28,28))
		var label = art.text("",Rect2(35,22,37,35),tag,28,Color("fff0c2"))
		var sale = art.button("sale",shop_rect(Rect2(tag_positions[index]+Vector2(40,-20),Vector2(50,50))),art._lock.bind(index))
		var sale_label = art.text("",Rect2(Vector2.ZERO,sale.size),sale,21,Color("ffdd53"))
		var locked = art.text("",shop_rect(Rect2(tag_positions[index]+Vector2(-85,60),Vector2(170,30))),art.ui,21)
		art.prices.append({"tag":tag,"label":label,"sale":sale,"sale_label":sale_label,"lock":locked})
	art.hero_hud = compact_hud(art)
	for index in 2:
		var action = Expedition.menus.shell.symbol(art.ui,["previous","next"][index],["左转","右转"][index],art._touch_action.bind(index),Vector2(88,78))
		action.position = Vector2(1080+index*104,756);action.name = ["TouchRotateLeft","TouchRotateRight"][index]
		art.touch_buttons.append(action);action.hide()
static func compact_hud(art) -> Dictionary:
	art.picture("class_badge",Rect2(1787,710,108,50),art.ui)
	art.picture("plate2",Rect2(1360,1017,560,63),art.ui,true)
	var result = {"name":art.text("",Rect2(1801,710,100,50),art.ui,28)}
	for index in 2:
		var x = 1439+index*265
		var rect = Rect2(x,1035,203,34)
		art.picture("plate3",rect,art.ui)
		var bar = TextureProgressBar.new();bar.texture_progress = art.texture("health" if index==0 else "stamina");bar.nine_patch_stretch = true
		bar.position=rect.position;bar.size=rect.size;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.ui.add_child(bar)
		result["health" if index==0 else "stamina"]=bar
		result["hp_text" if index==0 else "sp_text"]=art.text("",rect,art.ui,24)
		art.text("生命" if index==0 else "耐力",Rect2(x-57,1031,57,40),art.ui,24)
	result["status_icons"]=HBoxContainer.new();art.ui.add_child(result.status_icons);result.status_icons.hide();result["status_signature"]=""
	result["statuses"]=art.text("",Rect2(0,0,1,1),art.ui,14);result.statuses.hide()
	return result
static func combat(art):
	art.hero_hud = art._hud(Rect2(386,887,568,152),"玩家")
	art.enemy_hud = art._hud(Rect2(966,887,568,152),"敌人")
	combat_shadows(art)
	art.picture("timeline_base",Rect2(746,26,490,61),art.ui)
	var progress = TextureProgressBar.new(); progress.name="ArtTimeline";progress.texture_progress=art.texture("timeline_fill")
	progress.position=Vector2(747,25);progress.size=Vector2(487,20);progress.nine_patch_stretch=true;progress.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.ui.add_child(progress)
	# 暂停图标要落在时间轴底图的圆形凹槽里并上下左右都居中：hud_timeline_base.png 为 560x70，
	# 凹槽纵向占 15~69 像素，映射到 Rect2(746,26,490,61) 后其竖直中心约为 y=62.6；
	# 图标贴图 37x36 按 32x36 居中缩放后实绘高 31，故 rect y=45 时图标中心与凹槽中心重合。
	# 横向实测：贴图 560x70 缩放 0.8714（KEEP_ASPECT_CENTERED 上下留白 1px）后，
	# 凹槽中心（贴图列 231~327 的中心 279）落在舞台 x≈990，图标中心 = rect.x+16，故 rect x 取 974，再按视觉右移 1px 定为 975。
	art.button("play",Rect2(975,45,32,36),func():
		if Expedition.flow.combat_paused:Game.combatTimer.unpause()
		else:Game.combatTimer.onPauseButtonPressed()).name="CombatPausePlay"
	REF.zone(art.ui,Rect2(958,38,66,57),func():
		if Expedition.flow.combat_paused:Game.combatTimer.unpause()
		else:Game.combatTimer.onPauseButtonPressed()).name="CombatPauseTarget"
	var speed=REF.zone(art.ui,Rect2(1240,12,78,59),Game.combatTimer.onFastButtonPressed);speed.name="CombatSpeed"
	art.text("×1",Rect2(0,0,78,59),speed,40).name="SpeedCaption"
	art.button("settings",Rect2(1822,14,59,59),Expedition.show_settings).name="Action_combat_settings"

static func combat_shadows(art):
	art.picture("shadow",Rect2(43,1026,344,49),art.scenery)
	art.picture("shadow",Rect2(1548,1026,300,49),art.scenery)
