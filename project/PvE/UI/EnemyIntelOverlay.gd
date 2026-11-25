extends Control
## 路线页之上的二级敌情弹窗：遮罩 + 纸面，一页同时展示敌情与带颜色的敌人背包。
## 不替换底层路线画布，关闭后仍停在原来的路线页。

const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const ENEMY_ART = preload("res://PvE/Art/NewArtCatalog.gd")

var page_ref
var node_data: Dictionary
var phase: int = 0

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
	_picture("intel_paper", Rect2(282, 185, 1366, 692), true)
	var left := _picture("intel_flourish", Rect2(600, 261, 176, 35))
	left.flip_h = true
	_picture("intel_flourish", Rect2(1145, 261, 176, 35))
	REF.text(self, ui.words("敌方情报", "Enemy intel"), Rect2(782, 241, 356, 74), 48)
	_icon_button("close", Rect2(1562, 158, 101, 106), close)
	var portrait_path: String = page_ref.portrait_path(node_data)
	var texture: Texture2D = AssetStream.resources.get(portrait_path) if AssetStream.resources.has(portrait_path) else load(portrait_path)
	var portrait: TextureRect = ui.picture(self, texture, Vector2.ZERO)
	portrait.position = Vector2(330, 407)
	portrait.size = Vector2(281, 333)
	portrait.modulate = ENEMY_ART.enemy_variant(node_data).tint
	_picture("intel_name", Rect2(337, 757, 267, 53), true)
	REF.text(self, owner.enemy_name(node_data), Rect2(343, 757, 255, 53), 29, Color("fff2cc"))
	_build_phases()
	_build_intel()
	_build_bag()

func _build_phases() -> void:
	var snapshot: Dictionary = page_ref.owner.detail_views.enemy_snapshot(node_data)
	var phases: Array = snapshot.get("boss_phases", [])
	for index in phases.size():
		var target := int(phases[index].phase)
		var button := REF.button(self, "intel_name", Rect2(646 + index * 116, 327, 106, 44), func(): _set_phase(target), str(target), 23)
		button.disabled = target == phase

func _set_phase(target: int) -> void:
	if phase == target:
		return
	phase = target
	build()

func _build_intel() -> void:
	var owner = page_ref.owner
	_picture("intel_plate", Rect2(611, 384, 399, 440), true)
	var detail := VBoxContainer.new()
	detail.position = Vector2(629, 400)
	detail.size = Vector2(360, 400)
	add_child(detail)
	var snapshot: Dictionary = owner.detail_views.enemy_snapshot(node_data)
	if snapshot.get("ok", false):
		owner.label("♥ %s    ◆ %s" % [snapshot.base_stats.max_health, snapshot.base_stats.stamina_max], detail, 24)
	page_ref.ui.text_pages(detail, page_ref.ability_text(node_data), 354, 285, 21)

func _build_bag() -> void:
	var owner = page_ref.owner
	var grid: Control = owner.detail_views.grid(owner.enemy_build(node_data, phase), self, _empty_tile())
	grid.position = Vector2(1041, 384)

## 空格底图走新美术的浅色格，让敌人背包的占用/空格颜色分得清。
func _empty_tile() -> Texture2D:
	var path: String = preload("res://PvE/Art/SuppliedArt.gd").ui_path("cell_empty")
	if path.is_empty():
		path = "res://Art/Supplied20261102/ui/ui_cell_empty.png"
	return load(path)

## 弹窗按需同步补齐纸面贴图：REF 只从 AssetStream 缓存取图，
## 路线页的 popup 作用域里没有这些情报页资源，直接取会是空图。
func _ensure_assets() -> void:
	var paths: Array = REF.paths(["intel_paper", "intel_flourish", "intel_plate", "intel_name", "close", "board_guide"])
	paths.append(page_ref.portrait_path(node_data))
	for path in paths:
		if AssetStream.resources.get(path) == null:
			AssetStream.resources[path] = load(path)

## 直接按路径取图，避免依赖执行时机的资源缓存。
func _picture(key: String, rect: Rect2, exact: bool = false) -> TextureRect:
	var node := TextureRect.new()
	node.name = "Ref_" + key
	node.texture = _texture(key)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE if exact else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	node.set_meta("reference_rect", rect)
	return node

func _texture(key: String) -> Texture2D:
	var path: String = REF.path(key)
	var cached: Texture2D = AssetStream.resources.get(path)
	return cached if cached != null else load(path)

func _icon_button(key: String, rect: Rect2, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _texture(key)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	add_child(button)
	return button

func _focus_first() -> void:
	if not is_inside_tree():
		return
	for control in find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled):
			control.grab_focus()
			return
