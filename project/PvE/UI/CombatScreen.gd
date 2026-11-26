extends Control
## Renders the projected battle state. Native actors and item grids stay in the world.

const CombatVM = preload("res://Code/Runtime/ViewModel/CombatVM.gd")
const STATUS_BADGES = preload("res://PvE/Art/StatusBadges.gd")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const ART_KEYS = ["name", "plate2", "plate3", "health", "stamina", "play", "pause", "timeline_base", "timeline_fill", "settings"]

var _model: CombatVM
var _art: Dictionary
var _font: Font
var _status_source: Dictionary
var _displayed_revision := -1
var _sides: Array[Dictionary] = []

func grid_origin(side: int) -> Vector2:
	var marker: Marker2D = $PlayerGrid if side == 0 else $EnemyGrid
	return marker.global_position

func bind(model: CombatVM, art: Dictionary, font: Font, status_source: Dictionary) -> Error:
	if model == null or font == null:
		return ERR_INVALID_PARAMETER
	for key in ART_KEYS:
		if not art.get(key) is Texture2D:
			return ERR_INVALID_PARAMETER
	for key in ["is_negative", "texture", "name"]:
		var provider = status_source.get(key)
		if not provider is Callable or not provider.is_valid():
			return ERR_INVALID_PARAMETER
	_disconnect_model()
	_model = model
	_art = art.duplicate()
	_font = font
	_status_source = status_source.duplicate()
	_displayed_revision = -1
	for hud in _sides:
		hud.status_signature = ""
	if is_inside_tree():
		_connect_model()
	if is_node_ready():
		_apply_art()
		_render()
	return OK

func _enter_tree() -> void:
	_connect_model()
	_render.call_deferred()

func _exit_tree() -> void:
	_disconnect_model()
	_displayed_revision = -1

func _connect_model() -> void:
	if _model != null and not _model.changed.is_connected(_render):
		_model.changed.connect(_render)

func _disconnect_model() -> void:
	if _model != null and _model.changed.is_connected(_render):
		_model.changed.disconnect(_render)

func _ready() -> void:
	for side in [$PlayerHud, $EnemyHud]:
		_restore_packed_layout(side)
		_sides.append({
			"name": side.get_node("NameCaption"),
			"health": side.get_node("HealthBar"),
			"stamina": side.get_node("StaminaBar"),
			"hp_text": side.get_node("HealthValue"),
			"sp_text": side.get_node("StaminaValue"),
			"status_icons": side.get_node("Buffs"),
			"debuff_icons": side.get_node("Debuffs"),
			"statuses": side.get_node("StatusText"),
			"status_signature": "",
		})
	for button in [$CombatPausePlay, $Action_combat_settings]:
		button.mouse_entered.connect(_button_feedback.bind(button, Color(1.10, 1.06, 1.0)))
		button.mouse_exited.connect(_button_feedback.bind(button, Color.WHITE))
	if _model != null:
		_apply_art()
		_render()

# Workaround (2026-11-24): in exported builds the engine drops the stored
# offsets of children belonging to an editable sub-instance (the enemy HUD),
# piling its parts up at (0,0). The packed scene records stay correct, so the
# layout is re-applied from them: base scene first, then this scene's overrides.
func _restore_packed_layout(side: Control) -> void:
	for child in side.get_children():
		if not child is Control:
			continue
		for source in [[side.scene_file_path, "./"], [scene_file_path, "./%s/" % side.name]]:
			if source[0] == null or not load(source[0]) is PackedScene:
				continue
			var state: SceneState = (load(source[0]) as PackedScene).get_state()
			var path := String(source[1]) + String(child.name)
			for index in state.get_node_count():
				if str(state.get_node_path(index)) != path:
					continue
				for prop in state.get_node_property_count(index):
					var key := str(state.get_node_property_name(index, prop))
					if key.begins_with("offset_") or key.begins_with("anchor_") or key.begins_with("grow_"):
						child.set(key, state.get_node_property_value(index, prop))

func _apply_art() -> void:
	for side in [$PlayerHud, $EnemyHud]:
		side.get_node("PanelArt").texture = _art.plate2
		side.get_node("NameArt").texture = _art.name
		side.get_node("HealthTrack").texture = _art.plate3
		side.get_node("StaminaTrack").texture = _art.plate3
		side.get_node("HealthBar").texture_progress = _art.health
		side.get_node("StaminaBar").texture_progress = _art.stamina
	$TimelineBase.texture = _art.timeline_base
	$ArtTimeline.texture_progress = _art.timeline_fill
	$Action_combat_settings.texture_normal = _art.settings
	$CombatPausePlay.texture_normal = _art.play
	for label in find_children("*", "Label", true, false):
		label.add_theme_font_override("font", _font)

func _render() -> void:
	if _model == null or not is_inside_tree() or not is_node_ready() or _displayed_revision == _model.screen_revision():
		return
	_displayed_revision = _model.screen_revision()
	var state := _model.screen_state()
	for button in [$CombatPausePlay, $CombatPauseTarget, $CombatSpeed, $Action_combat_settings]:
		button.disabled = state.is_empty()
	if state.is_empty():
		hide()
		return
	show()
	var chinese := str(state.locale).begins_with("zh")
	$ArtTimeline.value = 100.0 * float(state.playback_time) / maxf(0.01, float(state.elapsed_time))
	$CombatSpeed/SpeedCaption.text = "×" + str(int(state.speed))
	$CombatPausePlay.texture_normal = _art.play if state.paused else _art.pause
	for side in [$PlayerHud, $EnemyHud]:
		side.get_node("HealthCaption").text = "生命" if chinese else "Health"
		side.get_node("StaminaCaption").text = "耐力" if chinese else "Stamina"
	_update_side(_sides[0], state.player, chinese)
	_update_side(_sides[1], state.enemy, chinese)
	for child in find_children("*", "Label", true, false):
		_fit_label(child, float(state.ui_scale))

func _update_side(hud: Dictionary, stats: Dictionary, chinese: bool) -> void:
	hud.name.text = stats.name
	hud.health.value = 100.0 * float(stats.health) / maxf(1.0, float(stats.max_health))
	hud.stamina.value = 100.0 * float(stats.stamina) / maxf(1.0, float(stats.max_stamina))
	hud.hp_text.text = "%d / %d" % [ceili(float(stats.health)), ceili(float(stats.max_health))]
	hud.sp_text.text = "%.1f / %.1f" % [float(stats.stamina), float(stats.max_stamina)]
	STATUS_BADGES.render(hud, stats.statuses, int(stats.armor), _badge_text, _status_source, chinese)

func _badge_text(value: String, rect: Rect2, parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.set_meta("art_font_size", font_size)
	parent.add_child(label)
	return label

func _fit_label(label: Label, scale_factor: float) -> void:
	var nominal := int(label.get_meta("art_font_size", 24))
	var font_size := roundi(nominal * scale_factor)
	var lines := label.text.split("\n")
	while font_size > 14:
		var width := 0.0
		for line in lines:
			width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if width <= label.size.x - 6 and _font.get_height(font_size) * lines.size() <= label.size.y:
			break
		font_size -= 1
	var snapped := int(REF.font_step(font_size))
	label.add_theme_font_size_override("font_size", snapped if snapped <= font_size else font_size)
	# Button captions use the shared visual-centre compensation; HUD readouts keep their own layout.
	if label.get_parent() is BaseButton and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		REF.center_label(label)

func _button_feedback(button: BaseButton, tint: Color) -> void:
	if button.disabled:
		return
	var tween := button.create_tween().set_ignore_time_scale(true)
	tween.tween_property(button, "modulate", tint, 0.10)

func _on_pause_play() -> void:
	if _model != null:
		_model.request_screen_action(&"pause_play")

func _on_speed() -> void:
	if _model != null:
		_model.request_screen_action(&"speed")

func _on_settings() -> void:
	if _model != null:
		_model.request_screen_action(&"settings")
