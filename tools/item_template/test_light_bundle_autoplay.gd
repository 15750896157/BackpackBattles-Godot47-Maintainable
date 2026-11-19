extends SceneTree

## 灯光刀·动画包无头实测：三包加载/结构/动画播放。
## -s 模式无 autoload：包一律不进 SceneTree（避免 FlickerAnimation.gd 的 Util 引用报错），
## 动画验证 = 手动 play + advance（autoplay 语义等价：进树时自动 play 同名动画）。

func _initialize() -> void:
	var fails := 0
	# (场景, AnimationPlayer 节点名, 动画名, 是否验证播放)
	var cases := [
		["res://PvE/Items/Anims/ThorsHammerAnim.tscn", "Idle", "Flash", true],
		["res://PvE/Items/Anims/BurningTorchAnim.tscn", "AnimationPlayer", "Flicker", true],
		["res://PvE/Items/Anims/BurningTorchAnim.tscn", "FlickerAnimation", "Flicker", false],
		["res://PvE/Items/Anims/OilLampAnim.tscn", "FlickerAnimation", "Flicker", false],
	]
	for case in cases:
		var packed = load(case[0])
		if packed == null:
			print("FAIL_LOAD " + case[0])
			fails += 1
			continue
		var inst = packed.instantiate()
		var player = inst.get_node_or_null(case[1])
		if player == null or not (player is AnimationPlayer):
			print("FAIL_PLAYER " + case[0] + ":" + case[1])
			fails += 1
			continue
		if not player.has_animation(case[2]):
			print("FAIL_ANIM " + case[0] + ":" + case[2])
			fails += 1
			continue
		if case[3]:
			player.play(case[2])
			player.advance(0.05)
			if not player.is_playing():
				print("FAIL_PLAY " + case[0] + ":" + case[2])
				fails += 1
				continue
			print("OK_PLAY " + case[0] + ":" + case[1] + "/" + case[2])
		else:
			print("OK_PRESENT " + case[0] + ":" + case[1] + "/" + case[2])
		inst.free()
	# OilLamp 包结构：根=TorchLight(Sprite2D)、FlickerAnimation 挂根下
	var oil = load("res://PvE/Items/Anims/OilLampAnim.tscn").instantiate()
	if not (oil is Sprite2D) or oil.get_node_or_null("FlickerAnimation") == null:
		print("FAIL_STRUCTURE OilLampAnim")
		fails += 1
	else:
		print("OK_STRUCTURE OilLampAnim (root=TorchLight Sprite2D + FlickerAnimation)")
	oil.free()
	# ThorsHammer 包结构：包根 use_parent_material=true（WithLight 材质继承链穿透包根）
	var th = load("res://PvE/Items/Anims/ThorsHammerAnim.tscn").instantiate()
	if not th.use_parent_material:
		print("FAIL_STRUCTURE ThorsHammerAnim (root use_parent_material)")
		fails += 1
	else:
		print("OK_STRUCTURE ThorsHammerAnim (root use_parent_material=true)")
	th.free()
	print("RESULT fails=", fails)
	quit(1 if fails > 0 else 0)
