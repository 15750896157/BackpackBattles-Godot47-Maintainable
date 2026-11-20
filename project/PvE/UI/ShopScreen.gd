extends Control
## Shop overlay. The host supplies the resident actors, shelf and command targets.

signal menu_requested(action: StringName)

const ShopVM = preload("res://Code/Runtime/ViewModel/ShopVM.gd")
const ART_KEYS = ["codex", "journey", "refresh", "coin", "battle", "settings", "plate1", "price", "sale",
	"class_badge", "plate2", "plate3", "health", "stamina", "previous", "next"]
const SCENERY_KEYS = ["shelf", "merchant", "table", "storage_mat", "sell"]
const TWO_LINE_DISCOUNT_HEIGHT = 53.0

var _model: ShopVM
var _art: Dictionary
var _font: Font
var _read_display: Callable
var _prices: Array[Dictionary] = []
var _labels: Array[Node] = []
var _offer_state: Array = []

func bind(model: ShopVM, art: Dictionary, font: Font, read_display: Callable) -> Error:
	if model == null or font == null or not read_display.is_valid() or not _has_textures(art, ART_KEYS):
		return ERR_INVALID_PARAMETER
	_disconnect_model()
	_model = model
	_art = art.duplicate()
	_font = font
	_read_display = read_display
	if is_inside_tree():
		_connect_model()
	if is_node_ready():
		_apply_art()
		refresh_display()
	return OK

static func apply_scenery(scenery: Node2D, art: Dictionary) -> Error:
	if scenery == null or not _has_textures(art, SCENERY_KEYS):
		return ERR_INVALID_PARAMETER
	_apply_textures(scenery, art)
	return OK

static func _has_textures(art: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not art.get(key) is Texture2D:
			return false
	return true

static func _apply_textures(root: Node, art: Dictionary) -> void:
	for node in root.find_children("*", "Control", true, false):
		if not node.has_meta("shop_texture"):
			continue
		var texture: Texture2D = art[node.get_meta("shop_texture")]
		if node is TextureButton:
			node.texture_normal = texture
		elif node is TextureProgressBar:
			node.texture_progress = texture
		else:
			node.texture = texture

func _enter_tree() -> void:
	_connect_model()
	refresh_display.call_deferred()

func _exit_tree() -> void:
	_disconnect_model()

func _connect_model() -> void:
	if _model != null and not _model.changed.is_connected(refresh_display):
		_model.changed.connect(refresh_display)

func _disconnect_model() -> void:
	if _model != null and _model.changed.is_connected(refresh_display):
		_model.changed.disconnect(refresh_display)

func _ready() -> void:
	for index in 5:
		var panel := get_node("Offer%d" % index)
		var tag: TextureButton = panel.get_node("PriceTag")
		var sale: TextureButton = panel.get_node("SaleBadge")
		var discount_label: Label = sale.get_node("Discount")
		_prices.append({"tag": tag, "sale": sale, "label": tag.get_node("Price"),
			"sale_label": discount_label, "discount_height": discount_label.size.y, "lock": panel.get_node("Lock")})
		tag.pressed.connect(_toggle_lock.bind(index))
		sale.pressed.connect(_toggle_lock.bind(index))
	$Action_refresh.pressed.connect(_refresh_stock)
	$ArtStartBattle.pressed.connect(_start)
	$Action_codex.pressed.connect(menu_requested.emit.bind(&"codex"))
	$Action_journey.pressed.connect(menu_requested.emit.bind(&"journey"))
	$Action_shop_settings.pressed.connect(menu_requested.emit.bind(&"settings"))
	for button in find_children("*", "TextureButton", true, false):
		button.mouse_entered.connect(_feedback.bind(button, Color(1.10, 1.06, 1.0)))
		button.mouse_exited.connect(_feedback.bind(button, Color.WHITE))
	for button in rotation_buttons():
		var icon: TextureRect = button.get_node("Icon")
		button.button_down.connect(icon.set_modulate.bind(Color(0.75, 0.82, 0.77)))
		button.button_up.connect(icon.set_modulate.bind(Color.WHITE))
	$TouchRotateLeft.pressed.connect(_rotate.bind(false))
	$TouchRotateRight.pressed.connect(_rotate.bind(true))
	_labels = find_children("*", "Label", true, false)
	if _model != null:
		_apply_art()
		refresh_display()

func _apply_art() -> void:
	_apply_textures(self, _art)
	for label in _labels:
		label.add_theme_font_override("font", _font)
		# The original shop lays out each label at its base size before applying UI scaling.
		label.add_theme_font_size_override("font_size", int(label.get_meta("art_font_size")))
		label.size = label.size.max(label.get_combined_minimum_size())

func price_badge(index: int) -> Dictionary:
	return _prices[index].duplicate()

func rotation_buttons() -> Array[Button]:
	return [$TouchRotateLeft, $TouchRotateRight]

func refresh_from_host() -> void:
	if _model != null:
		_model.refresh()
		refresh_display()

## Call on host presentation ticks, including native shelf replacement and drag state.
func refresh_display() -> void:
	if _model == null or not is_inside_tree() or not is_node_ready():
		return
	var state := _model.snapshot()
	# Event and rest pages share the shop carrier, so the overlay steps aside for them
	# and must come back once the flow returns to the shop.
	visible = state.mode == "SHOP_PREPARE"
	if not visible:
		return
	var host: Dictionary = _read_display.call()
	var chinese := str(host.locale).begins_with("zh")
	var shop: Dictionary = state.shop
	_offer_state = shop.slots
	$GoldValue.text = str(state.gold)
	$RefreshCost.text = str(shop.refresh_cost)
	$ArtStartBattle/StageNumber.text = ("关卡 %d-%d" if chinese else "Stage %d-%d") % [state.act, state.step]
	$ArtStartBattle/StageCaption.text = _stage_caption(state, chinese)
	$ArtStartBattle.disabled = not shop.controls.can_start
	$Action_refresh.disabled = not shop.controls.can_refresh
	for button in rotation_buttons():
		button.visible = shop.controls.can_rotate
	_update_prices(shop, host.offers, chinese)
	$ClassName.text = host.name
	$HealthBar.value = 100.0 * float(host.health) / maxf(1.0, float(host.max_health))
	$StaminaBar.value = 100.0 * float(host.stamina) / maxf(1.0, float(host.max_stamina))
	$HealthValue.text = "%d / %d" % [ceili(float(host.health)), ceili(float(host.max_health))]
	$StaminaValue.text = "%.1f / %.1f" % [float(host.stamina), float(host.max_stamina)]
	$HealthCaption.text = "生命" if chinese else "Health"
	$StaminaCaption.text = "耐力" if chinese else "Stamina"
	for label in _labels:
		_fit_label(label, float(host.ui_scale))

func _stage_caption(state: Dictionary, chinese: bool) -> String:
	if state.route_pending:
		return "选择路线" if chinese else "Choose route"
	if state.node_type == "merchant":
		return "前进" if chinese else "Continue"
	return "开战" if chinese else "Battle"

func _update_prices(shop: Dictionary, native_offers: Array, chinese: bool) -> void:
	for index in _prices.size():
		var badge := _prices[index]
		var offer: Dictionary = _offer_state[index] if index < _offer_state.size() else {}
		var native: Dictionary = native_offers[index] if index < native_offers.size() else {}
		var shown: bool = not offer.is_empty() and not bool(offer.sold) and not native.is_empty() and (
			native.definition_id == offer.definition_id and int(native.generation) == int(shop.generation))
		badge.tag.visible = shown
		badge.sale.visible = shown and bool(offer.get("discounted", false))
		badge.sale_label.visible = badge.sale.visible
		badge.tag.disabled = not shop.controls.can_lock
		badge.sale.disabled = badge.tag.disabled
		badge.label.text = str(offer.get("price", 0))
		var discount := float(offer.get("discount_pct", 0.0))
		if chinese:
			badge.sale_label.size.y = maxf(badge.sale_label.size.y, TWO_LINE_DISCOUNT_HEIGHT)
		badge.sale_label.text = str(snappedf((1.0 - discount) * 10.0, 0.1)) + "\n折" if chinese else "-%d%%" % roundi(discount * 100.0)
		if not chinese:
			badge.sale_label.size.y = badge.discount_height
		badge.lock.text = ("已锁定" if chinese else "Locked") if shown and bool(offer.get("locked", false)) else ""

func _fit_label(label: Label, scale_factor: float) -> void:
	var font_size := roundi(int(label.get_meta("art_font_size")) * scale_factor)
	var lines := label.text.split("\n")
	while font_size > 14:
		var width := 0.0
		for line in lines:
			width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if width <= label.size.x - 6 and _font.get_height(font_size) * lines.size() <= label.size.y:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

func _feedback(button: TextureButton, tint: Color) -> void:
	if not button.disabled:
		button.create_tween().set_ignore_time_scale(true).tween_property(button, "modulate", tint, 0.10)

func _toggle_lock(index: int) -> void:
	refresh_display()
	if _model != null and is_visible_in_tree() and _prices[index].tag.visible:
		_model.set_lock(index, not bool(_offer_state[index].locked))

func _refresh_stock() -> void:
	if _model != null and is_visible_in_tree():
		_model.refresh_shop()

func _start() -> void:
	if _model != null and is_visible_in_tree():
		_model.start_or_choose_route()

func _rotate(clockwise: bool) -> void:
	if _model != null and is_visible_in_tree():
		_model.rotate_held(clockwise)
