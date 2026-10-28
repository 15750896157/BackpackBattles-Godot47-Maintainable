extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Sound.gd")

static func _ready(subject: Receiver):
	for i in range(30):
		var player = AudioStreamPlayer.new()
		player.name = "SoundPlayer" + str(i)
		subject.soundPlayers.add_child(player)
		player.bus = "SFX"
		player.connect("finished", Callable(subject, "returnPlayer").bind(player))
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		subject.availableSoundPlayers.append(player)
	for i in range(5):
		var player = AudioStreamPlayer.new()
		player.name = "SoundPlayer_process" + str(i)
		subject.soundPlayers.add_child(player)
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.connect("finished", Callable(subject, "returnPlayer").bind(player))
		subject.availableSoundPlayers_process.append(player)

	subject.loadBGM()

static func fadeOutBGM(subject: Receiver, fadeOutTime: float):
	subject.scene_music.cancel()

	Util.killTween(subject.tween)
	subject.tween = subject.get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	subject.tween.tween_method(Callable(subject, "setLinearVolume").bind(subject.bgmPlayer2), db_to_linear(subject.bgmPlayer2.volume_db), 0.0, fadeOutTime)
	subject.tween.parallel().tween_method(Callable(subject, "setLinearVolume").bind(subject.bgmPlayer1), db_to_linear(subject.bgmPlayer1.volume_db), 0.0, fadeOutTime)

static func playBGM_loop(subject: Receiver, loop, intro, volume, delay):
	subject.scene_music.cancel()
	Util.killTween(subject.tween)
	subject.tween = subject.create_tween().set_parallel(true)

	subject.setStream(loop, subject.bgmPlayer1, linear_to_db(0))
	subject.setStream(intro, subject.bgmPlayer2, volume)

	subject.tween.tween_method(Callable(subject, "setLinearVolume").bind(subject.bgmPlayer1), 0.0, db_to_linear(volume), 2).set_delay(delay)
	subject.tween.tween_method(Callable(subject, "setLinearVolume").bind(subject.bgmPlayer2), db_to_linear(volume), 0.0, 2).set_delay(delay)

static func playRising(subject: Receiver, stream: AudioStream, volume: float, pitch: float, process_when_paused):

	var pitchData
	if subject.risingPitchSounds.has(stream):
		pitchData = subject.risingPitchSounds[stream]
	else:
		pitchData = subject.PitchData.new()
		subject.risingPitchSounds[stream] = pitchData

	var stackedPitch = pitchData.play()

	if process_when_paused:
		return subject.playSound_process(stream, volume, stackedPitch * pitch)
	else:
		return subject.playSound(stream, volume, stackedPitch * pitch)

static func playLooping(subject: Receiver, stream: AudioStream, duration: float, volume: float, pitch: float):
	var player = subject.playSound(stream, volume, pitch)
	if player:
		var tween2 = subject.get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		tween2.tween_method(Callable(subject, "setLinearVolume").bind(player), 0.0, db_to_linear(volume), subject.loopFadeInTime)
		var delay = duration - subject.loopFadeInTime - subject.loopFadeOutTime
		tween2.tween_method(Callable(subject, "setLinearVolume").bind(player), db_to_linear(volume), 0.0, subject.loopFadeOutTime).set_delay(delay)
		tween2.tween_callback(Callable(subject, "returnPlayer").bind(player)).set_delay(duration)

	return player

static func pve_bus(subject: Receiver, stream: AudioStream) -> StringName:
	if not Expedition.initialized or AudioServer.get_bus_index("PvEUI") < 0: return &"SFX"
	var path = stream.resource_path.to_lower()
	if "ambient" in path or "ambience" in path or "birds" in path: return &"PvEAmbient"
	if Expedition.active and Expedition.flow.screen_state in ["COMBAT_RUNNING", "COMBAT_RESULT"]: return &"PvECombat"
	return &"PvEUI"
