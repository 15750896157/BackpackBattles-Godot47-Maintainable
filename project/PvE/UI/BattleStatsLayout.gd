extends RefCounted

const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const KEYS = ["stats_paper", "stats_vs", "stats_column", "close", "result_gold"]

static func show_page(page, sides: Array) -> void:
	var owner = page.owner
	var ui = page.ui
	var root: Control = ui.open_canvas("COMBAT_LOG", ui.words("战斗统计","Battle statistics"))
	var epoch: int = owner.popup_epoch
	if not await AssetStream.prepare(REF.paths(KEYS), "popup"):
		if is_instance_valid(root) and epoch == owner.popup_epoch:
			owner.close_popup()
		return
	if not is_instance_valid(root) or epoch != owner.popup_epoch:
		return
	REF.picture(root, "stats_paper", Rect2(506,235,908,670), true)
	REF.picture(root, "stats_vs", Rect2(885,286,150,134))
	REF.button(root, "close", Rect2(1347,187,99,103), owner.view_return).name = "CloseMenu"
	for index in sides.size():
		var left := 552.0 if index == 0 else 1020.0
		var side: Dictionary = sides[index]
		var heading := REF.text(root, side.heading, Rect2(left,306,348,78), 40)
		heading.name = "LootStats_%d" % index
		REF.picture(root, "stats_column", Rect2(left,408,348,400), true)
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(left+20,425)
		scroll.size = Vector2(308,362)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root.add_child(scroll)
		var content: VBoxContainer = ui.column(scroll)
		owner.label(side.summary, content, 22)
		for line in side.items:
			owner.label(line, content, 21)
		if side.has_totals:
			owner.label(side.totals_heading, content, 23)
		for entry in side.statuses:
			owner.label(entry.text, content, 21).set_meta("pve_status_total", entry.meta)
		if not side.stamina.is_empty():
			owner.label(side.stamina, content, 21)
	REF.button(root, "result_gold", Rect2(839,826,242,55),
		func(): page.log_page(0,true), ui.words("查看事件","View events"), 24).name = "LogEvents"
	REF.fade_in(root)
	owner.focus_popup()
