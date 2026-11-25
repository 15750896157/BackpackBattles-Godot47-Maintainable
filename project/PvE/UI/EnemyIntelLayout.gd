extends RefCounted

const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const KEYS = ["intel_paper", "intel_flourish", "intel_plate", "intel_name", "close", "board_guide"]

static func show_page(page, node: Dictionary, phase: int) -> void:
	var owner = page.owner
	var ui = page.ui
	var from_route: bool = owner.current_page == "ROUTE_SELECT"
	var title: String = ui.words("敌方情报", "Enemy intel")
	var root: Control = ui.open_canvas("INTEL", title)
	var epoch: int = owner.popup_epoch
	var portrait_path: String = page.portrait_path(node)
	var art_paths := REF.paths(KEYS) + [portrait_path]
	if from_route: art_paths.append(REF.path("route_background"))
	# 旧路线画布已被 clear_popup 移除；新画布若空着等资源，会露出一帧主菜单。
	# 从路线页进来时先铺一层纯色底，等资源就绪后再画正式背景与情报纸。
	if from_route and is_instance_valid(root):
		var hold := ColorRect.new()
		hold.size = root.size
		hold.color = Color(0.04,0.03,0.02)
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(hold)
	if not await AssetStream.prepare(art_paths, "popup"):
		if is_instance_valid(root) and epoch == owner.popup_epoch:
			owner.close_popup()
		return
	if not is_instance_valid(root) or epoch != owner.popup_epoch:
		return
	if from_route:
		REF.picture(root,"route_background",Rect2(0,0,1920,1080),true)
		var shade := ColorRect.new()
		shade.size = root.size
		shade.color = Color(0.04,0.03,0.02,0.56)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	REF.picture(root, "intel_paper", Rect2(282,185,1366,692), true)
	var ornament := REF.picture(root, "intel_flourish", Rect2(600,261,176,35))
	ornament.flip_h = true
	REF.picture(root, "intel_flourish", Rect2(1145,261,176,35))
	REF.text(root, title, Rect2(782,241,356,74), 48)
	REF.button(root, "close", Rect2(1562,158,101,106), owner.view_return).name = "CloseMenu"

	var portrait: TextureRect = ui.picture(root, AssetStream.resources.get(portrait_path), Vector2.ZERO)
	portrait.position = Vector2(330,407)
	portrait.size = Vector2(281,333)
	portrait.modulate = preload("res://PvE/Art/NewArtCatalog.gd").enemy_variant(node).tint
	REF.picture(root, "intel_name", Rect2(337,757,267,53), true)
	REF.text(root, owner.enemy_name(node), Rect2(343,757,255,53), 29, Color("fff2cc"))

	REF.picture(root, "intel_plate", Rect2(625,378,399,440), true)
	var detail := VBoxContainer.new()
	detail.position = Vector2(643,394)
	detail.size = Vector2(360,400)
	root.add_child(detail)
	var snapshot: Dictionary = owner.detail_views.enemy_snapshot(node)
	if snapshot.get("ok", false):
		owner.label("♥ %s    ◆ %s" % [snapshot.base_stats.max_health,snapshot.base_stats.stamina_max], detail, 24)
	ui.text_pages(detail, page.ability_text(node), 354, 285, 21)

	var phases: Array = snapshot.get("boss_phases", [])
	for index in phases.size():
		var target := int(phases[index].phase)
		var button := REF.button(root, "intel_name", Rect2(1041 + index * 116,327,106,44),
			func(): page.show_page(node,target), str(target), 23)
		button.disabled = target == phase
	var grid: Control = owner.detail_views.grid(owner.enemy_build(node,phase), root, REF.texture("board_guide"))
	grid.position = Vector2(1041,384)
	REF.fade_in(root)
	owner.focus_popup()
