extends CanvasLayer
## 开发者模式：Alt+N 打开 / 关闭。
## 左侧直接照图鉴（BookLayout）的样式：书签页签切大类 + 卡片列表 + 翻页 + 搜索。
## 右侧不再自绘：直接露出游戏商店页里那套真实背包（原生 Inventory / Item / Bag 节点、
## 原生拖拽与摆放），交互逻辑与商店完全一致。仅在商店页（SHOP_PREPARE）可用。

const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const PAGE_SIZE := 6
const TAB_RULES := [
	["武器", ["weapon", "ranged"]],
	["护甲", ["armor"]],
	["消耗", ["potion", "herb", "healing", "cleanse", "burn", "poison"]],
	["材料", ["material", "elite_loot"]],
	["功能", ["utility", "spatial", "economy", "stamina"]],
	["战斗", ["tempo", "heavy", "combo", "counter", "slow", "vulnerable", "burst", "focused_build", "true_damage", "hold"]],
]
const CARD_SIZE := Vector2(304, 282)
const COLUMN_X := [170.0, 490.0]
const ROW_Y := [196.0, 486.0, 776.0]
const KEYS := ["camp", "book_pages", "close", "button", "previous", "next",
	"bookmark_blue", "bookmark_purple", "bookmark_gold", "bookmark_red", "bookmark_green",
	"badge_blue", "badge_gold", "badge_purple"]

var db
var placement

var groups: Array = []
var active: String = "bags"
var page: int = 0
var query: String = ""

var root: Control
var cards: Control
var search_box: LineEdit
var status_label: Label
var info_label: Label
var caption_label: Label
var page_label: Label
var prev_button: TextureButton
var next_button: TextureButton
var tabs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("developer_mode")
	db = Expedition.db
	placement = Expedition.flow.placement
	_build_groups()
	if not await AssetStream.prepare(REF.paths(KEYS), "popup"):
		return
	var waited := 0
	while Expedition.ui_font == null and waited < 180:
		await get_tree().process_frame
		waited += 1
	_build_layout()
	populate()


func _build_groups() -> void:
	groups = []
	var buckets: Dictionary = {}
	for rule in TAB_RULES:
		buckets[str(rule[0])] = []
	for row in db.rows("items"):
		var tag := str(row.get("tags", "")).get_slice("|", 0)
		var placed := false
		for rule in TAB_RULES:
			if not tag.is_empty() and (rule[1] as Array).has(tag):
				buckets[str(rule[0])].append(row)
				placed = true
				break
		if not placed:
			if not buckets.has("其他"):
				buckets["其他"] = []
			buckets["其他"].append(row)
	groups.append({"id": "bags", "caption": "背包", "kind": "bag", "rows": db.rows("bags")})
	for rule in TAB_RULES:
		var key := str(rule[0])
		groups.append({"id": "cat:" + key, "caption": key, "kind": "item", "rows": buckets[key]})
	if buckets.has("其他") and not buckets["其他"].is_empty():
		groups.append({"id": "cat:其他", "caption": "其他", "kind": "item", "rows": buckets["其他"]})


func _build_layout() -> void:
	root = Control.new()
	root.name = "Root"
	root.size = Vector2(1920, 1080)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# 左半页整体挡住点击，避免点穿到下面商店的货架；右半页保持透明，
	# 让商店真实的背包格子和原生道具照常接收鼠标。
	var shield := Control.new()
	shield.name = "LeftShield"
	shield.position = Vector2.ZERO
	shield.size = Vector2(948, 1080)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shield)
	REF.picture(root, "book_pages", Rect2(16, 16, 932, 1048), true)
	REF.text(root, "开发者模式 · 造物录", Rect2(52, 36, 330, 54), 34)
	REF.button(root, "close", Rect2(1824, 34, 78, 82), close, "", 24)
	search_box = LineEdit.new()
	search_box.name = "DevSearch"
	search_box.placeholder_text = "搜索：名称 / ID / 图片名"
	search_box.position = Vector2(400, 38)
	search_box.size = Vector2(380, 52)
	search_box.add_theme_font_override("font", Expedition.ui_font)
	search_box.add_theme_font_size_override("font_size", 22)
	search_box.add_theme_color_override("font_color", REF.INK)
	search_box.add_theme_color_override("font_placeholder_color", Color(0.47, 0.34, 0.19, 0.55))
	for state in ["normal", "focus", "read_only"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.45)
		box.set_corner_radius_all(8)
		box.set_border_width_all(2)
		box.border_color = Color(0.45, 0.32, 0.18, 0.55) if state == "focus" else Color(0.45, 0.32, 0.18, 0.30)
		search_box.add_theme_stylebox_override(state, box)
	search_box.text_changed.connect(_on_query_changed)
	root.add_child(search_box)
	REF.button(root, "button", Rect2(796, 38, 100, 52), clear_inventory, "清空", 20)

	var colors := ["blue", "purple", "gold", "red", "green"]
	tabs.clear()
	var count: int = groups.size()
	var gap := 4.0
	var tab_width: float = (860.0 - gap * maxi(0, count - 1)) / maxi(1, count)
	for index in count:
		var group: Dictionary = groups[index]
		var tab := REF.button(root, "bookmark_" + colors[index % colors.size()],
			Rect2(36.0 + index * (tab_width + gap), 94, tab_width, 64), _switch_group.bind(str(group.id)), str(group.caption), 22)
		tab.name = "DevTab_" + str(group.id)
		tabs[str(group.id)] = tab

	caption_label = REF.text(root, "", Rect2(170, 160, 624, 32), 21, Color("6b4a2d"))

	cards = Control.new()
	cards.name = "Cards"
	cards.position = Vector2.ZERO
	cards.size = Vector2(932, 1048)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cards)

	prev_button = REF.button(root, "previous", Rect2(306, 964, 64, 54), func(): _change_page(-1), "", 20)
	page_label = REF.text(root, "", Rect2(382, 964, 200, 54), 24)
	next_button = REF.button(root, "next", Rect2(594, 964, 64, 54), func(): _change_page(1), "", 20)

	info_label = REF.text(root, "", Rect2(964, 690, 560, 30), 20, REF.PAPER, 3)
	status_label = REF.text(root, "", Rect2(964, 724, 900, 30), 20, REF.PAPER, 3)
	REF.text(root, "点左侧道具＝直接放进背包；右侧拖动 / 旋转 / 放下与商店一致", Rect2(964, 758, 900, 30), 18, REF.PAPER, 3)


func _group(gid: String) -> Dictionary:
	for group in groups:
		if str(group.id) == gid:
			return group
	return {}


func _switch_group(gid: String) -> void:
	if gid == active and query.is_empty():
		return
	active = gid
	page = 0
	if not query.is_empty():
		query = ""
		search_box.text = ""
	populate()


func _refresh_tabs() -> void:
	for key in tabs:
		var tab = tabs[key]
		if is_instance_valid(tab):
			tab.modulate = Color.WHITE if str(key) == active else Color(0.78, 0.78, 0.78)


func _on_query_changed(text: String) -> void:
	query = text.strip_edges()
	page = 0
	populate()


## 搜索：同时匹配游戏名、定义 ID、图片源文件名（icon_ref）和标签中文名。
func _matches(row: Dictionary, needle: String) -> bool:
	if str(row.get("id", "")).to_lower().contains(needle):
		return true
	if db.text(str(row.get("name_key", ""))).to_lower().contains(needle):
		return true
	if str(row.get("icon_ref", "")).get_file().to_lower().contains(needle):
		return true
	for tag in str(row.get("tags", "")).split("|", false):
		if Expedition.detail_views.tag_name(str(tag)).to_lower().contains(needle):
			return true
	return false


func _visible_rows() -> Array:
	if query.is_empty():
		return _group(active).get("rows", [])
	var needle := query.to_lower()
	var hits: Array = []
	for group in groups:
		for row in group.rows:
			if _matches(row, needle):
				hits.append(row)
	return hits


func populate() -> void:
	if cards == null or not is_instance_valid(cards):
		return
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	_refresh_tabs()
	var rows: Array = _visible_rows()
	var last_page: int = maxi(0, int(ceil(float(rows.size()) / PAGE_SIZE)) - 1)
	page = clampi(page, 0, last_page)
	prev_button.disabled = page == 0
	next_button.disabled = page >= last_page
	page_label.text = "%d / %d" % [page + 1, last_page + 1]
	if query.is_empty():
		caption_label.text = "%s · 共 %d 件（含未上架）" % [str(_group(active).get("caption", "")), rows.size()]
	else:
		caption_label.text = "搜索「%s」· 共 %d 件（全部大类）" % [query, rows.size()]
	for index in range(page * PAGE_SIZE, mini(rows.size(), (page + 1) * PAGE_SIZE)):
		cards.add_child(_make_card(rows[index], index - page * PAGE_SIZE))
	_refresh_info()


func _make_card(row: Dictionary, slot: int) -> Button:
	var def_id := str(row.get("id", ""))
	var kind := "bag" if _is_bag(def_id) else "item"
	var card := Button.new()
	card.name = "DevCard_" + def_id
	card.position = Vector2(COLUMN_X[slot % 2], ROW_Y[slot / 2])
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.set_meta("definition_id", def_id)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.97, 0.89, 0.71, 0.96)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.45, 0.32, 0.18, 0.55)
	var hover_style := normal.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(1.0, 0.95, 0.80, 0.98)
	hover_style.border_color = Color(0.66, 0.46, 0.18, 0.75)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(1.0, 0.94, 0.76, 1.0)
	pressed_style.set_border_width_all(3)
	pressed_style.border_color = Color(0.78, 0.54, 0.18, 0.95)
	var focus_style := normal.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.78, 0.54, 0.18, 0.8)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", pressed_style)
	card.add_theme_stylebox_override("focus", focus_style)
	card.pressed.connect(_add_definition.bind(def_id))
	var image := TextureRect.new()
	image.name = "Icon"
	image.position = Vector2(63, 91)
	image.size = Vector2(178, 145)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)
	Expedition.detail_views.fill_icon(weakref(image), def_id, Expedition.popup_epoch)

	var released := kind == "bag" or str(row.get("shop_enabled", "true")).to_lower() == "true"
	var title: Label = REF.text(card, db.text(str(row.get("name_key", ""))),
		Rect2(16, 48, 272, 39), 25, REF.INK if released else Color("a2412f"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rarity := str(row.get("rarity", "common"))
	var first_tag := str(row.get("tags", "")).get_slice("|", 0)
	var subtitle: String = "背包 · " if kind == "bag" else ""
	subtitle += Expedition.t("rarity." + rarity + ".name")
	if kind == "item" and not first_tag.is_empty():
		subtitle += " · " + Expedition.detail_views.tag_name(first_tag)
	var sub: Label = REF.text(card, subtitle, Rect2(12, 241, 280, 32), 20, Color("70502f"))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_key := "badge_gold" if not released else "badge_purple" if rarity == "legendary" else "badge_blue" if rarity == "rare" else "badge_gold"
	var extent := Rect2(13, 10, 116, 37)
	REF.picture(card, badge_key, extent, true)
	var badge_color: Color = Color("a2412f") if not released else Color("fff7d6") if badge_key == "badge_purple" else REF.INK
	var badge: Label = REF.text(card, "未上架" if not released else Expedition.t("rarity." + rarity + ".name"), extent, 19, badge_color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _change_page(delta: int) -> void:
	page = maxi(0, page + delta)
	populate()


## 点图鉴卡片：直接把道具放进本局真实背包（走商店同一套 PlacementService），
## 之后的拿起 / 拖动 / 旋转 / 放下全部由原生 Item 与 NativeBuildBridge 处理。
func _add_definition(def_id: String) -> void:
	var flow = Expedition.flow
	if flow == null or flow.run.is_empty() or flow.screen_state != "SHOP_PREPARE":
		_status("请先在游戏中进入商店，右侧才是商店的真实背包。")
		return
	if Game.draggedItem != null:
		_status("先把手里这件放下。")
		return
	var entry := {"uid": "%s_dev_%d" % [str(flow.run.get("run_id", "run")), int(flow.run.get("next_uid", 1))],
		"definition_id": def_id, "x": 0, "y": 0, "rotation": 0}
	var result: Dictionary = placement.auto_place(flow.run.build, entry)
	if not bool(result.get("ok", false)):
		_status(_error_text(result))
		return
	flow.run.next_uid = int(flow.run.get("next_uid", 1)) + 1
	flow._update()
	await Expedition.bridge.render_build(Game.PLAYER, flow.run.build, Item.Owner.PlayerInventory)
	_refresh_info()
	_status("已放进背包：%s（在右侧拖到想要的位置）" % _name_of(def_id))


## 清空本局背包里的背包与道具，方便重新摆；仓库里的东西不动。
func clear_inventory() -> void:
	var flow = Expedition.flow
	if flow == null or flow.run.is_empty() or flow.screen_state != "SHOP_PREPARE":
		_status("当前不在商店页。")
		return
	if Game.draggedItem != null:
		_status("先把手里这件放下。")
		return
	flow.run.build["bags"] = []
	flow.run.build["items"] = []
	flow._update()
	await Expedition.bridge.render_build(Game.PLAYER, flow.run.build, Item.Owner.PlayerInventory)
	_refresh_info()
	_status("本局背包已清空（仓库保留）。")


func _name_of(def_id: String) -> String:
	return db.text(str(placement.definition(def_id).get("name_key", def_id)))


func _is_bag(def_id: String) -> bool:
	return not db.get_row("bags", def_id).is_empty()


func _refresh_info() -> void:
	if info_label == null or not is_instance_valid(info_label):
		return
	var flow = Expedition.flow
	if flow == null or flow.run.is_empty():
		info_label.text = "尚未开局"
		return
	var build: Dictionary = flow.run.get("build", {})
	info_label.text = "背包 %d 个 · 道具 %d 件" % [build.get("bags", []).size(), build.get("items", []).size()]


func _status(text: String) -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = text


func _error_text(result: Dictionary) -> String:
	match str(result.get("code", "")):
		"no_placement":
			return "背包里没有空位了，先清空或挪一挪。"
		"unsupported_item":
			return "这里没有背包覆盖，先放一个背包再放道具。"
		"overlap":
			return "目标格已经被占了。"
		"out_of_bounds":
			return "超出 9×7 背包范围。"
		"rotation":
			return "这个形状不支持当前朝向。"
	return str(result.get("message", result.get("error", "操作失败")))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()
