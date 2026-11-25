extends Control
## 路线页之上的二级敌情弹窗：遮罩 + 纸面 + 敌情/背包页签。
## 不替换底层路线画布，关闭后仍停在原来的路线页。

const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const ENEMY_ART = preload("res://PvE/Art/NewArtCatalog.gd")

var page_ref
var node_data: Dictionary
var phase: int = 0
var _tab: String = "abilities"

static func open(page, node: Dictionary, phase: int = 0) -> void:
	var owner = page.owner
	if owner == null or owner.panel == null:
		return
	for old in owner.get_tree().get_nodes_in_group("enemy_intel_overlay"):
		old.queue_free()
	var overlay = (load("res://PvE/UI/EnemyIntelOverlay.gd") as Script).new()
	owner.panel.add_child(overlay)
	overlay.setup(page, node, phase)

func setup(page, node: Dictionary, phase: int = 0) -> void:
	page_ref = page
	node_data = node
	self.phase = phase
	name = "EnemyIntelOverlay"
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("enemy_intel_overlay")
	_ensure_assets()
	build()
	call_deferred("_focus_first")

## 弹窗按需同步补齐纸面贴图：REF 只从 AssetStream 缓存取图，
## 而路线页的 popup 作用域里没有这些情报页资源，直接取会是空图。
func _ensure_assets() -> void:
	var paths: Array = REF.paths(["intel_paper", "intel_flourish", "intel_plate", "intel_name", "close", "board_guide"])
	paths.append(page_ref.portrait_path(node_data))
	for path in paths:
		if AssetStream.resources.get(path) == null:
			AssetStream.resources[path] = load(path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	page_ref.owner.focus_popup()
	queue_free()

func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var owner = page_ref.owner
	var ui = page_ref.ui
	var shade := ColorRect.new()
	shade.position = Vector2.ZERO
	shade.size = Vector2(1920, 1080)
	shade.color = Color(0.04, 0.03, 0.02, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	REF.picture(self, "intel_paper", Rect2(282, 185, 1366, 692), true)
	var left := REF.picture(self, "intel_flourish", Rect2(600, 261, 176, 35))
	left.flip_h = true
	REF.picture(self, "intel_flourish", Rect2(1145, 261, 176, 35))
	REF.text(self, ui.words("敌方情报", "Enemy intel"), Rect2(782, 241, 356, 74), 48)
	REF.button(self, "close", Rect2(1562, 158, 101, 106), close)
	var portrait_path: String = page_ref.portrait_path(node_data)
	var texture: Texture2D = AssetStream.resources.get(portrait_path) if AssetStream.resources.has(portrait_path) else load(portrait_path)
	var portrait: TextureRect = ui.picture(self, texture, Vector2.ZERO)
	portrait.position = Vector2(330, 407)
	portrait.size = Vector2(281, 333)
	portrait.modulate = ENEMY_ART.enemy_variant(node_data).tint
	REF.picture(self, "intel_name", Rect2(337, 757, 267, 53), true)
	REF.text(self, owner.enemy_name(node_data), Rect2(343, 757, 255, 53), 29, Color("fff2cc"))
	var intel_tab := REF.button(self, "intel_name", Rect2(801, 320, 152, 46), func(): _switch("abilities"), ui.words("敌情", "Intel"), 23)
	intel_tab.disabled = _tab == "abilities"
	var bag_tab := REF.button(self, "intel_name", Rect2(967, 320, 152, 46), func(): _switch("build"), ui.words("背包", "Backpack"), 23)
	bag_tab.disabled = _tab == "build"
	if _tab == "build":
		_build_bag()
	else:
		_build_intel()
	REF.fade_in(self)

func _switch(tab: String) -> void:
	if _tab == tab:
		return
	_tab = tab
	build()

func _set_phase(target: int) -> void:
	if phase == target:
		return
	phase = target
	build()

func _build_intel() -> void:
	var owner = page_ref.owner
	REF.picture(self, "intel_plate", Rect2(625, 378, 399, 440), true)
	var detail := VBoxContainer.new()
	detail.position = Vector2(643, 394)
	detail.size = Vector2(360, 400)
	add_child(detail)
	var snapshot: Dictionary = owner.detail_views.enemy_snapshot(node_data)
	if snapshot.get("ok", false):
		owner.label("♥ %s    ◆ %s" % [snapshot.base_stats.max_health, snapshot.base_stats.stamina_max], detail, 24)
	page_ref.ui.text_pages(detail, page_ref.ability_text(node_data), 354, 285, 21)
	var phases: Array = snapshot.get("boss_phases", [])
	for index in phases.size():
		var target := int(phases[index].phase)
		var button := REF.button(self, "intel_name", Rect2(1041 + index * 116, 327, 106, 44), func(): _set_phase(target), str(target), 23)
		button.disabled = target == phase

func _build_bag() -> void:
	var owner = page_ref.owner
	var grid: Control = owner.detail_views.grid(owner.enemy_build(node_data, phase), self, REF.texture("board_guide"))
	grid.position = Vector2(690, 384)

func _focus_first() -> void:
	if not is_inside_tree():
		return
	for control in find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled):
			control.grab_focus()
			return
