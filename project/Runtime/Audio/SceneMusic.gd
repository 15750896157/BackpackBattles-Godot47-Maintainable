extends RefCounted
## The requested track can differ from the currently audible track during fades.

var target

func cancel():
	target = null

func request(sound, stream, volume: float, fade_out: float):
	sound.bgmPlayer2.stop()
	sound.bgmPlayer2.stream = null
	var pending = sound.tween != null and sound.tween.is_valid() and sound.tween.is_running()
	if target == stream and pending:
		return
	target = stream
	Util.killTween(sound.tween)
	sound.tween = null
	var player = sound.bgmPlayer1
	if player.playing and player.stream == stream:
		# Cancel an opposite pending transition and restore the requested level.
		sound.setLinearVolume(db_to_linear(volume), player)
		return
	if fade_out == 0.0:
		sound.setStream(stream, player, volume)
		sound.setLinearVolume(db_to_linear(volume), player)
		return
	var transition = sound.create_tween()
	sound.tween = transition
	if player.playing and player.volume_db > -30.0:
		transition.tween_method(sound.setLinearVolume.bind(player), db_to_linear(player.volume_db), 0.0, fade_out)
	transition.tween_callback(sound.setStream.bind(stream, player, 0.0))
	transition.tween_method(sound.setLinearVolume.bind(player), 0.0, db_to_linear(volume), sound.crossFadeTime)
