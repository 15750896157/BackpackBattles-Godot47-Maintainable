extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Sound.gd")

static func returnPlayer(subject: Receiver, player: AudioStreamPlayer):
	if player.process_mode == subject.PROCESS_MODE_ALWAYS:
		if player not in subject.availableSoundPlayers_process: subject.availableSoundPlayers_process.insert(0, player)
	else:
		if player not in subject.availableSoundPlayers: subject.availableSoundPlayers.insert(0, player)

static func setStream(subject: Receiver, stream, bgmPlayer, volume):
	if subject.shutting_down: return
	bgmPlayer.bus = &"PvEAmbient" if Expedition.initialized and stream == subject.postFightBGM_survival else &"BGM"
	bgmPlayer.stream = stream
	bgmPlayer.volume_db = volume
	bgmPlayer.play()

static func pve_stop_scene_sounds(subject: Receiver):
	subject.itemMovePlayer.stop()
	subject.soundsPlayedThisFrame.clear()
	subject.risingPitchSounds.clear()
	for player in subject.soundPlayers.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			subject.returnPlayer(player)

static func playSound(subject: Receiver, stream: AudioStream, volume: float, pitch: float):
	if subject.shutting_down: return null
	if subject.availableSoundPlayers.size() > 0:
		if not subject.soundsPlayedThisFrame.has(stream):
			var player = subject.availableSoundPlayers.pop_back()
			player.bus = subject.pve_bus(stream)
			player.stream = stream
			player.volume_db = volume
			player.pitch_scale = pitch
			player.playing = true
			subject.soundsPlayedThisFrame[stream] = player
			return player
	return null

static func playSound_process(subject: Receiver, stream: AudioStream, volume: float, pitch: float):
	if subject.shutting_down: return null
	if subject.availableSoundPlayers_process.size() > 0:
		if not subject.soundsPlayedThisFrame.has(stream):
			var player = subject.availableSoundPlayers_process.pop_back()
			player.bus = subject.pve_bus(stream)
			player.stream = stream
			player.volume_db = volume
			player.pitch_scale = pitch
			player.playing = true
			subject.soundsPlayedThisFrame[stream] = player
			return player
	return null
