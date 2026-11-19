extends RefCounted
## Visually reviewed input mappings. Domain ids remain stable for old saves.
const ROOT="res://Art/Supplied20261102/"
const LATEST="res://Art/Supplied20261113/"
const LATEST_UI=["loading_0","loading_1","loading_2","loading_3","loading_5","loading_6","recipe_row","recipe_detail","detail_title","entry","hero_description","bag_description"]
const REFRESH="res://Art/Supplied20261109/"
const REFRESH_ACTORS=["hermit_crab","sand_lizard","lava_golem","werewolf","antlion","treant","spider"]
const REFRESH_UI=[
	"loading_camp","route_card","route_card_elite","route_warning","route_go","route_reward_slot",
	"route_header_chip","route_coin","camp_back","camp_heart","board_guide","possible_rewards_zh",
	"intel_paper","intel_flourish","intel_plate","intel_name",
	"result_shade","result_defeat_zh","result_victory_zh","result_reward_paper","result_warning",
	"result_red","result_gold","result_victory_ribbon","result_defeat_ribbon",
	"result_victory_crown","result_defeat_crown","result_victory_halo","result_defeat_halo","result_sparks",
	"stats_paper","stats_vs","stats_column","tooltip_paper","tooltip_rule",
	"badge_blue","badge_green","badge_gold","badge_purple","badge_red","book_entry","book_detail","book_pages",
]
const UI={
	"guide":"items/item_codex.png","home":"ui/ui_btn_arrow_red.png",
	"heart":"ui/ui_heart.png",
	"camp":"bg/bg_camp.png","route_background":"bg/bg_route.png",
	"route_card":"ui/ui_route_card.png","route_motif":"ui/ui_route_motif.png","route_tab":"ui/ui_route_tab.png","route_tab_danger":"ui/ui_route_tab_danger.png","route_tab_elite":"ui/ui_route_tab_elite.png","route_threat":"ui/ui_route_threat.png","route_warning":"ui/ui_route_warning.png",
	"book_cover":"ui/ui_book_cover.png","book_pages":"ui/ui_book_pages.png","bookmark_blue":"ui/ui_bookmark_blue.png","bookmark_purple":"ui/ui_bookmark_purple.png","bookmark_gold":"ui/ui_bookmark_gold.png","bookmark_red":"ui/ui_bookmark_red.png","bookmark_green":"ui/ui_bookmark_green.png",
	"select_armorer":"actors/actor_warrior.png","select_archer":"actors/actor_archer.png","select_alchemist":"actors/actor_mage.png",
	"title":"bg/bg_main_menu.png","selection":"bg/bg_interior_lodge.png",
	"button":"ui/ui_button_frame_yellow.png","button_blue":"ui/ui_button_frame_blue.png",
	"hand":"ui/ui_hand_hint.png","title_book":"ui/ui_codex_sign.png",
	"loading_base":"ui/ui_journey_frame.png","loading_fill":"ui/ui_journey_fill.png","loading_icon":"ui/ui_journey_emblem.png",
	"back":"ui/ui_btn_arrow_red.png","previous":"ui/ui_btn_arrow_gold.png","selection_shadow":"ui/ui_actor_shadow_wide.png",
	"window":"ui/ui_panel_parchment.png","settings_plate":"ui/ui_panel_plain.png","close":"ui/ui_btn_close.png",
	"check":"ui/ui_check_mark.png","checkbox":"ui/ui_checkbox.png","highlight":"ui/ui_row_light.png",
	"slider_fill":"ui/ui_btn_primary.png","slider_base":"ui/ui_bar_track.png","slider_knob":"ui/ui_icon_diamond.png","ornament":"ui/ui_divider.png",
	"shop":"shop/shop_vignette.png","sell":"shop/shop_sell_scroll.png","refresh":"shop/shop_refresh_bell.png",
	"merchant":"shop/shop_merchant.png","codex":"shop/shop_codex.png","journey":"shop/shop_enemy_intel.png",
	"price":"shop/shop_price_tag.png","sale":"shop/shop_dot.png","cell":"ui/ui_cell_filled.png","cell_empty":"ui/ui_cell_empty.png",
	"bag2":"bags/bag_02.png","bag4":"bags/bag_04.png","bag6_vertical":"bags/bag_06.png","bag9":"bags/bag_09_square.png","bag9_wide":"bags/bag_09_wide.png",
	"name":"hud/hud_name_banner.png","play":"hud/hud_icon_play.png","pause":"hud/hud_icon_pause.png","shadow":"hud/hud_actor_shadow.png",
	"health":"hud/hud_label_health.png","stamina":"hud/hud_label_stamina.png","plate1":"hud/hud_plate_life.png","plate2":"hud/hud_plate_status.png","plate3":"hud/hud_plate_stamina.png",
	"settings":"hud/hud_icon_settings.png","timeline_base":"hud/hud_timeline_base.png","timeline_fill":"hud/hud_timeline_fill.png",
}
const ACTORS={"armorer":"actor_warrior","archer":"actor_archer","alchemist":"actor_mage","goblin":"enemy_goblin","bat":"enemy_bat","skeleton":"enemy_skeleton","mummy":"enemy_mummy","snake":"enemy_snake","lava_snail":"enemy_lava_snail","moss_golem":"enemy_moss_golem","hermit_crab":"enemy_hermit_crab","sand_lizard":"enemy_sand_lizard","lava_golem":"enemy_lava_golem","werewolf":"enemy_werewolf","antlion":"enemy_antlion","boss":"boss_generic","final_boss":"boss_final"}
const STATUS={"poison":"poison","burn":"burn","armor":"armor","lifesteal":"lifesteal","spikes":"thorns","resistance":"resist","stamina_regen":"stamina_regen","cooldown":"cooldown"}
const ITEMS={
	"utility_knife":"dagger","iron_sword":"iron_longsword","broad_axe":"double_axe","heavy_cleaver":"battle_axe","hunting_spear":"spear",
	"plated_vest":"plate_armor","leather_wrap":"leather_armor","tower_shield":"holy_bulwark","travel_ration":"bread","sharpening_stone":"whetstone",
	"merchant_token":"token","focus_prism":"gem_purple","ember_stone":"flint","glass_bead":"gem_blue","field_manual":"codex",
	"duelist_mark":"priest_badge","layered_plates":"squire_armor","retaliation_spikes":"thorn_mail","salvage_pouch":"salvage_pouch",
	"lucky_coin":"honor_medal","healing_herb":"potted_plant","regeneration_leaf":"vine_ring","cleansing_salt":"holy_cross",
	"blood_cup":"vampire_fang","clockwork_spring":"copper_watch","arsenal_bracer":"jade_gloves","guardian_standard":"knight_seal",
	"resonant_bell":"thunder_ring","star_compass":"crown_crest","fracture_charm":"voodoo_doll","scout_lens":"mana_gem",
}
static func item_path(id:String)->String:
	if Expedition.db!=null:
		var configured=str(Expedition.db.get_row("items",id).get("icon_ref",""))
		if configured.begins_with(ROOT):return configured
	return ROOT+"items/item_"+ITEMS[id]+".png" if ITEMS.has(id) else ""
static func actor_path(key:String)->String:
	if key=="fire_knight":return LATEST+"fire_knight.png"
	if key in REFRESH_ACTORS:return REFRESH+"actors/enemy_"+key+".png"
	return ROOT+"actors/"+str(ACTORS.get(key,"enemy_skeleton"))+".png"
static func status_path(key:String)->String:
	return ROOT+"status/status_"+str(STATUS.get(key,key))+".png"
static func shop_actor_path(key:String)->String:
	return ROOT+"shop/shop_hero_"+str({"armorer":"warrior","archer":"archer","alchemist":"mage"}.get(key,"warrior"))+".png"
static func enemy_key(node:Dictionary)->String:
	if node.get("type","")=="boss":return "final_boss" if int(Expedition.flow.run.get("act",1))>=3 else "boss"
	var enemy=Expedition.db.get_row("enemy_builds",str(node.get("enemy_id","")))
	var archetype=str(enemy.get("archetype_id",""));var chapter=int(Expedition.flow.run.get("act",1))
	match archetype:
		"burning_bastion":return "fire_knight"
		"quick_striker":return "bat" if chapter==1 else "werewolf"
		"shield_line":return "treant" if chapter==3 else "moss_golem"
		"venom_brewer":return "goblin" if chapter==1 else "snake"
		"field_mender":return "goblin" if chapter==1 else "mummy"
		"toxic_guard":return "spider"
		"ember_runner":return "lava_snail"
		"gear_conductor":return "antlion"
		"heavy_breaker":return "hermit_crab" if chapter<3 else "lava_golem"
		"counter_wall":return "hermit_crab"
	return "sand_lizard" if chapter==2 else "skeleton"
static func enemy_variant(node:Dictionary)->Dictionary:
	# Presentation only: distinguish shared silhouettes without changing combat
	# data, global RNG, contour or facing direction.
	var enemy=Expedition.db.get_row("enemy_builds",str(node.get("enemy_id","")))
	var archetype=str(enemy.get("archetype_id",""))
	if node.get("type","")=="boss" and int(Expedition.flow.run.get("act",1))==2:return {"tint":Color(0.84,0.93,1.0),"scale":1.10}
	if archetype=="field_mender":return {"tint":Color(1.0,0.91,0.78),"scale":1.08}
	if archetype=="counter_wall":return {"tint":Color(0.84,0.91,1.0),"scale":0.92}
	if archetype=="toxic_guard":return {"tint":Color(0.85,0.93,0.81),"scale":1.08}
	return {"tint":Color.WHITE,"scale":1.0}
