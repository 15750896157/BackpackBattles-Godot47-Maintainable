extends RefCounted
var owner
var ui
func _init(host,shell): owner=host;ui=shell
func show_page():
	ui.open("UI_GUIDE",ui.words("操作教程","How to play"))
	if owner.active and owner.flow.run.get("difficulty_id","")=="tutorial":
		var steps=owner.flow.tutorial.active(owner.flow.profile_service.profile,owner.flow.run,owner.flow.screen_state,not CraftingManager.pve_candidates().is_empty())
		if not steps.is_empty():
			owner.label(owner.t(steps[0].title_key),null,29)
			owner.label(owner.t(steps[0].body_key),null,24)
			var actions=ui.row()
			ui.action(actions,ui.words("返回练习","Practice"),owner.view_return)
			ui.action(actions,ui.words("跳过引导","Skip guidance"),func():owner.flow.skip_tutorial();owner.view_return()).name="SkipTutorial"
	var grid=ui.grid(owner.popup_content,3)
	var entries=[
		["battle","出战","Battle","整理好背包后，点右上方开战挂牌。","Arrange your backpack, then tap the hanging battle sign."],
		["codex","合成与图鉴","Craft & collect","点物品查看右侧详情；选配方后直接合成。","Tap an item for inline details. Select a recipe to craft."],
		["journey","路线与敌情","Journey & enemies","路线卡片直接前进，敌人头像显示本页情报。","Route cards travel directly. Enemy portraits show inline intel."],
		["hand","触摸与拖动","Move items","点按拿放，拿起后点左右箭头旋转、红叉放回；拖动背包才显示空格。","Pick and place. Use the arrows to rotate or the red cross to return a held item."],
		["continue","保存与继续","Save & continue","房屋图标保存返回；点标准或教学入口，再点继续游戏。","Save with the house. Open Standard or Tutorial, then choose Continue game."],
		["guide","购买与出售","Buy & sell","商店物品拖入背包或仓库；拖到出售图案可卖出。","Move shop items to your bag or storage. Drop on the sale sign to sell."]]
	for entry in entries:
		var card=VBoxContainer.new();card.custom_minimum_size=Vector2(400,235);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
		ui.picture(card,ui.image(entry[0]),Vector2(100,100))
		var title=owner.label(ui.words(entry[1],entry[2]),card,28);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		owner.label(ui.words(entry[3],entry[4]),card,23)
