extends RefCounted
## Six cards per sheet, inline descriptions, explicit text and list page buttons.
const PAGE_SIZE=6
const CATEGORIES=[["items","物品","Items"],["bags","背包","Bags"],["recipes","合成","Recipes"],["enemies","敌人","Enemies"],["rules","规则","Rules"],["records","记录","Records"]]
var owner
var ui
var category="items"
var query=""
var page=0
var only_seen=false
var only_available=false
var record_mode=0
var listing:VBoxContainer
var detail:VBoxContainer
func _init(host,shell):owner=host;ui=shell
func show_page(section:String=""):
	if not section.is_empty():category=section;page=0
	owner.detail_views.category=category
	ui.open("CRAFTING" if category=="recipes" and owner.active and owner.flow.screen_state=="SHOP_PREPARE" else "CODEX",ui.words("图鉴与合成","Collection & crafting"))
	var tabs=ui.row()
	for entry in CATEGORIES:ui.segment(tabs,ui.words(entry[1],entry[2]),func():category=entry[0];page=0;show_page(),category==entry[0])
	if category not in ["records","rules"]:
		var filters=ui.row()
		ui.segment(filters,ui.words("全部","All"),func():only_seen=false;only_available=false;page=0;show_page(),not only_seen and not only_available)
		ui.segment(filters,ui.words("已发现","Discovered"),func():only_seen=true;only_available=false;page=0;show_page(),only_seen)
		if category=="recipes" and owner.active and owner.flow.screen_state=="SHOP_PREPARE":ui.segment(filters,ui.words("可以合成","Craftable"),func():only_available=true;only_seen=false;page=0;show_page(),only_available)
	var body=ui.row();listing=ui.column(body,820);detail=ui.column(body,580)
	owner.detail_views.results=listing;populate()
func populate():
	if not is_instance_valid(listing):return
	ui.clear(listing);ui.clear(detail);owner.popup_epoch+=1;AssetStream.release("popup");owner.bindings.texture_cache.clear()
	if category=="records":records();return
	if category=="rules":dictionary();return
	var profile=owner.flow.profile_service.profile
	var source=owner.db.rows("enemy_builds")+owner.db.rows("bosses") if category=="enemies" else owner.db.rows(category)
	var available={}
	if owner.active and owner.flow.screen_state=="SHOP_PREPARE":
		for candidate in CraftingManager.pve_candidates():available[candidate.recipe_id]=candidate
	var matches:Array=[]
	for data in source:
		var id=str(data.get("result_item_id",data.id)) if category=="recipes" else str(data.id)
		var title=owner.t(owner.flow.placement.definition(id).name_key) if category=="recipes" else owner.t(data.get("name_key",data.id))
		var known=data.id in profile.recipes if category=="recipes" else data.id in profile.seen_enemies if category=="enemies" else data.id in profile.seen_items
		if only_seen and not known:continue
		if only_available and not available.has(data.id):continue
		if not query.is_empty() and (not known or not (title+" "+str(data.get("tags",""))).to_lower().contains(query.to_lower())):continue
		matches.append({"data":data,"id":id,"title":title if known or (only_available and available.has(data.id)) else ui.words("未发现","Unknown"),"known":known,"candidate":available.get(data.id,{}) if category=="recipes" else {}})
	var count=maxi(1,ceili(matches.size()/float(PAGE_SIZE)));page=clampi(page,0,count-1)
	var grid=ui.grid(listing,3)
	for index in range(page*PAGE_SIZE,mini((page+1)*PAGE_SIZE,matches.size())):
		var entry=matches[index];var card=ui.card(grid,entry.title,null,func():show_detail(entry))
		card.custom_minimum_size=Vector2(220,180);card.set_meta("definition_id",entry.id)
		var image=card.get_child(0).get_child(0)
		if category=="enemies":image.texture=owner.menus.journey.portrait(enemy_node(entry.data))
		else:owner.detail_views.fill_icon(weakref(image),entry.id,owner.popup_epoch)
		if not entry.known:image.modulate=Color(0.15,0.18,0.14)
	page_buttons(listing,count,populate)
	if not matches.is_empty():show_detail(matches[page*PAGE_SIZE])
	else:owner.label(ui.words("暂无内容","Nothing here yet"),detail,26)
	if category=="recipes" and not owner.menus.runs.selected_recipe.is_empty():craft_detail(owner.menus.runs.selected_recipe)
func page_buttons(parent:Node,count:int,callback:Callable):
	var nav=ui.row(parent)
	var previous=ui.symbol(nav,"previous",ui.words("上一页","Previous"),func():page=maxi(0,page-1);callback.call());previous.disabled=page==0;previous.name="ListPrevious"
	owner.label(str(page+1)+" / "+str(count),nav,23)
	var next=ui.symbol(nav,"next",ui.words("下一页","Next"),func():page=mini(count-1,page+1);callback.call());next.disabled=page+1>=count;next.name="ListNext"
func enemy_node(data:Dictionary)->Dictionary:return {"type":"boss" if data.has("persistent_rule_id") else "normal_combat","boss_id":data.id if data.has("persistent_rule_id") else "","enemy_id":data.id,"affix_id":data.get("affix_id","")}
func show_detail(entry:Dictionary):
	ui.clear(detail)
	if category=="recipes" and not entry.candidate.is_empty():craft_detail(entry.candidate);return
	if category=="enemies":
		if entry.known:owner.menus.journey.inline_intel(enemy_node(entry.data),detail)
		else:owner.label(entry.title,detail,28)
		return
	var top=ui.row(detail);var image=ui.picture(top,null,Vector2(100,90));owner.detail_views.fill_icon(weakref(image),entry.id,owner.popup_epoch)
	owner.label(entry.title,top,27)
	if not entry.known:
		if category=="recipes":
			var terms:Array[String]=[]
			for ingredient in owner.db.rows("recipe_ingredients"):
				if ingredient.recipe_id==entry.data.id:
					var tags=owner.db.list_values(owner.flow.placement.definition(ingredient.item_id).get("tags",""));terms.append(owner.detail_views.tag_name(str(tags[0])) if not tags.is_empty() else "?")
			ui.text_pages(detail," + ".join(terms)+" → ?",560,270,23)
		return
	ui.text_pages(detail,owner.detail_views.definition_text(entry.id),560,270,22)
	if category=="recipes":
		var materials=ui.row(detail)
		for ingredient in owner.db.rows("recipe_ingredients"):
			if ingredient.recipe_id==entry.data.id:owner.detail_views.fill_icon(weakref(ui.picture(materials,null,Vector2(60,60))),ingredient.item_id,owner.popup_epoch)
func craft_detail(candidate:Dictionary):
	ui.clear(detail)
	owner.label(owner.t(owner.flow.placement.definition(candidate.result_item_id).name_key),detail,27)
	var materials=ui.row(detail)
	for material in candidate.material_entries:owner.detail_views.fill_icon(weakref(ui.picture(materials,null,Vector2(64,64))),material.definition_id,owner.popup_epoch)
	owner.label("→",materials,26);owner.detail_views.fill_icon(weakref(ui.picture(materials,null,Vector2(84,84))),candidate.result_item_id,owner.popup_epoch)
	ui.text_pages(detail,owner.detail_views.definition_text(candidate.result_item_id),560,180,21)
	ui.action(detail,ui.words("合成","Craft"),func():
		var result=owner.flow.craft(candidate.recipe_id,{"material_uids":candidate.material_uids});owner.menus.runs.selected_recipe={};owner.perform(result)
		if result.ok:Sound.playSound(load("res://Assets/Sound/Craft.ogg"),-8);show_page("recipes"),not candidate.preview_ok).set_meta("recipe_id",candidate.recipe_id)
func records():
	var tabs=ui.row(listing)
	ui.segment(tabs,ui.words("成就","Achievements"),func():record_mode=0;page=0;populate(),record_mode==0)
	ui.segment(tabs,ui.words("历程","History"),func():record_mode=1;page=0;populate(),record_mode==1)
	var profile=owner.flow.profile_service.profile;var source=owner.db.rows("achievements") if record_mode==0 else profile.run_history
	var count=maxi(1,ceili(source.size()/6.0));page=clampi(page,0,count-1)
	for index in range(page*6,mini((page+1)*6,source.size())):
		var data=source[index]
		owner.label(("✓ " if data.id in profile.achievements else "○ ")+owner.t(data.name_key) if record_mode==0 else owner.t(owner.db.get_row("characters",data.character_id).name_key)+" · "+owner.t("ui.run_cleared" if data.clear else "ui.run_failed"),listing,23)
	page_buttons(listing,count,populate)
	for character in owner.db.rows("characters"):owner.label(owner.t(character.name_key)+"  "+str(profile.character_clears.get(character.id,[]).size())+" ★",detail,26)
	ui.action(detail,ui.words("战斗记录","Battle record"),owner.show_combat_log)
func dictionary():
	var source=owner.detail_views.rules.dictionary(TranslationServer.get_locale())
	var count=maxi(1,source.size());page=clampi(page,0,count-1)
	if not source.is_empty():
		owner.label(str(source[page].term),listing,30)
		ui.text_pages(listing,str(source[page].definition),760,330,25)
	page_buttons(listing,count,populate)
	var entries:Array[String]=[]
	for data in owner.db.rows("encounter_affixes"):
		if data.id in owner.flow.profile_service.profile.seen_affixes:entries.append(owner.detail_views.rules.affix(data,TranslationServer.get_locale()))
	if not entries.is_empty():ui.text_pages(detail,"\n\n".join(entries),560,380,23)
