extends RefCounted
## Presentation follows committed transactions and never changes run data or RNG.

var owner
var popup_tween: Tween
var popup_origin = Vector2.ZERO
var sale_count = 0
var coin_bursts = 0
var closing_ghost: TextureRect

func _init(expedition):
	owner = expedition

func reduced(key: String) -> bool:
	return owner.preferences != null and bool(owner.preferences.values.get(key, false))

func reveal_popup():
	if is_instance_valid(closing_ghost): closing_ghost.queue_free(); closing_ghost = null
	if popup_tween != null and popup_tween.is_valid(): popup_tween.kill()
	owner.panel.position = Vector2(110, 20)
	owner.panel.modulate = Color.WHITE
	owner.modal_shield.modulate = Color.WHITE
	popup_origin = owner.panel.position
	var duration = 0.08 if reduced("reduce_motion") else 0.18
	owner.panel.modulate.a = 0.0
	owner.modal_shield.modulate.a = 0.0
	if not reduced("reduce_motion"): owner.panel.position.y += 12.0
	popup_tween = owner.create_tween().set_parallel().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	popup_tween.tween_property(owner.panel, "modulate:a", 1.0, duration)
	popup_tween.tween_property(owner.modal_shield, "modulate:a", 1.0, duration)
	popup_tween.tween_property(owner.panel, "position", popup_origin, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_popup():
	if owner.panel.visible and DisplayServer.get_name() != "headless" and not reduced("reduce_effects") and not owner.art.curtain.busy:
		if is_instance_valid(closing_ghost): closing_ghost.queue_free()
		var image = owner.get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			var atlas = AtlasTexture.new(); atlas.atlas = ImageTexture.create_from_image(image)
			atlas.region = owner.get_viewport().get_final_transform() * owner.panel.get_global_rect()
			closing_ghost = TextureRect.new(); closing_ghost.texture = atlas
			closing_ghost.process_mode = Node.PROCESS_MODE_ALWAYS
			closing_ghost.position = owner.panel.position; closing_ghost.size = owner.panel.size
			closing_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; closing_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			owner.overlay.add_child(closing_ghost)
			var fade = closing_ghost.create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			fade.tween_property(closing_ghost,"modulate:a",0.0,0.08 if reduced("reduce_motion") else 0.16)
			fade.tween_callback(closing_ghost.queue_free)
	if popup_tween != null and popup_tween.is_valid(): popup_tween.kill()
	owner.panel.position = Vector2(110, 20)
	owner.panel.modulate = Color.WHITE
	owner.modal_shield.modulate = Color.WHITE

func sell(box, item, amount: int):
	sale_count += 1
	Sound.playSound(box.openSound)
	box.chomp()
	item.prepareDiscard()
	Util.reparentNode(item, Game.shopItemYSort)
	var duration = 0.08 if reduced("reduce_motion") else 0.4
	var visual = item.create_tween().set_parallel()
	visual.tween_property(item, "global_position", box.bottomPos.global_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	visual.tween_property(item.sprite, item.getScaleProp(), item.spriteScale * 0.12, duration * 0.6).set_delay(duration * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	visual.tween_property(item, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	visual.chain().tween_callback(Callable(item, "discard"))
	if amount > 0 and not reduced("reduce_effects") and not reduced("reduce_motion"):
		var flight = owner.create_tween()
		flight.tween_interval(0.18)
		flight.tween_callback(_coins.bind(box.getGoldPos(), Game.PLAYER.getGoldPos(), amount))

func _coins(origin: Vector2, destination: Vector2, amount: int):
	if not owner.active or Game.state != Game.State.Shop: return
	# Coin count is visual only; the authoritative sale was already saved once.
	var coins = Game.shootGold(origin, destination, clampi(amount, 1, 16))
	coins.visibility_rect = Rect2(Vector2.ZERO, destination - origin).abs().grow(256.0)
	coins.add_to_group("pve_sale_coins")
	coins.z_index = maxi(Game.getCoinSellboxLayer(), Game.getCoinPlayerLayer())
	coin_bursts += 1
	Sound.playSound(Game.SELLBOX.coinSpitSound, -8)
