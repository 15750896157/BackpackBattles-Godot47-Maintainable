extends RefCounted
## Cosmetic motion is relative to the fitted footprint, never a legacy zero.
static func activate(item, kind: int, consume: bool):
	item.resetSprite()
	if item.dragged or not is_instance_valid(item.sprite): return
	var origin: Vector2 = item.get_meta("pve_sprite_position", Vector2.ZERO)
	var reduced = Expedition.preferences != null and bool(Expedition.preferences.values.reduce_motion)
	if reduced: return
	var offset = Vector2(0,-10)
	var turn = 0.0
	if kind in [Item.ActivationAni.Slash,Item.ActivationAni.DoubleSlash,Item.ActivationAni.Chop,Item.ActivationAni.Bonk]:
		offset = Vector2(9,-5);turn = 0.10
	elif kind in [Item.ActivationAni.Stab,Item.ActivationAni.ReverseStab,Item.ActivationAni.Shoot]:
		offset = Vector2(11,-4)
	if item.isOwnedByOpponent(): offset.x = -offset.x;turn = -turn
	var tween = item.create_tween().set_trans(Tween.TRANS_QUAD)
	item.shadowTween = tween
	tween.tween_property(item.sprite,"position",origin+offset,0.09).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item.sprite,"rotation",turn,0.09)
	tween.tween_property(item.sprite,"position",origin,0.16).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(item.sprite,"rotation",0.0,0.16)
	if consume: tween.tween_property(item.sprite,"modulate:a",0.25,0.12)
