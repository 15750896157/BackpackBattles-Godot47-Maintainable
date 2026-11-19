extends Node2D

@onready var soundPlayers = $SoundPlayers

@onready var bgmPlayer1 = $BGMPlayer1
@onready var bgmPlayer2 = $BGMPlayer2
@onready var itemMovePlayer = $ItemMoveAudio

@onready var MASTER_BUS = AudioServer.get_bus_index("Master")
@onready var BGM_BUS = AudioServer.get_bus_index("BGM")
@onready var SFX_BUS = AudioServer.get_bus_index("SFX")
@onready var VOICE_BUS = AudioServer.get_bus_index("Voice")

var availableSoundPlayers: Array
var availableSoundPlayers_process: Array
var soundsPlayedThisFrame: Dictionary
var risingPitchSounds: Dictionary
var hoverSoundReadyTime = 0.0
var shutting_down: bool = false

func shutdown():
	shutting_down = true
	scene_music.cancel()
	Util.killTween(tween)
	tween = null
	for player in find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	soundsPlayedThisFrame.clear()
	risingPitchSounds.clear()

var bgmTracks: Dictionary

var castSoundCounter: int = 0
var tween
var scene_music = preload("res://Runtime/Audio/SceneMusic.gd").new()

const MIN_DB = - 60

func _ready():
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd")._ready(self)

func returnPlayer(player: AudioStreamPlayer):
	return load("res://Runtime/Behavior/Features/Utility/SoundBehavior.gd").returnPlayer(self, player)

func getBGMVolume():
	return db_to_linear(AudioServer.get_bus_volume_db(BGM_BUS))

func setBGMVolume(vol: float):
	AudioServer.set_bus_volume_db(BGM_BUS, linear_to_db(vol))

func isBGMmuted():
	return AudioServer.is_bus_mute(BGM_BUS)

func muteBGM(mute: bool):
	AudioServer.set_bus_mute(BGM_BUS, mute)

func getSFXVolume():
	return db_to_linear(AudioServer.get_bus_volume_db(SFX_BUS))

func setSFXVolume(vol: float):
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(vol))

func isSFXmuted():
	return AudioServer.is_bus_mute(SFX_BUS)

func muteSFX(mute: bool):
	AudioServer.set_bus_mute(SFX_BUS, mute)

func getVoiceVolume():
	return db_to_linear(AudioServer.get_bus_volume_db(VOICE_BUS))

func setVoiceVolume(vol: float):
	AudioServer.set_bus_volume_db(VOICE_BUS, linear_to_db(vol))

func muteVoice(mute: bool):
	AudioServer.set_bus_mute(VOICE_BUS, mute)

func isVoiceMuted():
	return AudioServer.is_bus_mute(VOICE_BUS)

func fadeOutBGM(fadeOutTime: float = 0.5):
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd").fadeOutBGM(self, fadeOutTime)

const crossFadeTime = 2.0

func playBGM(stream, volume = 0.0, fadeOutTime: float = 0.5):
	if shutting_down: return
	scene_music.request(self, stream, volume, fadeOutTime)

func playBGM_loop(loop, intro, volume = 0.0, delay = 3.0):
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd").playBGM_loop(self, loop, intro, volume, delay)

# 2026-11-18 版权清理：按用户要求移除全部纯音乐（BGM）。
# 原 playSurvivalBGM / playLobbyBGM / playSwitchModeBGM / playSubclassBGM / playLastTryBGM
# 五个函数及 16 个 BGM preload 常量已删除，游戏不再播放任何背景音乐。

func setLinearVolume(vol: float, player: AudioStreamPlayer):
	player.volume_db = linear_to_db(vol)

func setStream(stream, bgmPlayer, volume):
	return load("res://Runtime/Behavior/Features/Utility/SoundBehavior.gd").setStream(self, stream, bgmPlayer, volume)

func setMuffledSound(muffled: bool):
	AudioServer.set_bus_effect_enabled(BGM_BUS, 1, muffled)

func pve_stop_scene_sounds():
	return load("res://Runtime/Behavior/Features/Utility/SoundBehavior.gd").pve_stop_scene_sounds(self)

func playRising(stream: AudioStream, volume: float = 0, pitch: float = 1, process_when_paused = false):
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd").playRising(self, stream, volume, pitch, process_when_paused)

func playSound(stream: AudioStream, volume: float = 0, pitch: float = 1):
	return load("res://Runtime/Behavior/Features/Utility/SoundBehavior.gd").playSound(self, stream, volume, pitch)

const loopFadeInTime = 0.1
const loopFadeOutTime = 0.2

func playLooping(stream: AudioStream, duration: float, volume: float = 0, pitch: float = 1):
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd").playLooping(self, stream, duration, volume, pitch)

func playSound_process(stream: AudioStream, volume: float = 0, pitch: float = 1):
	return load("res://Runtime/Behavior/Features/Utility/SoundBehavior.gd").playSound_process(self, stream, volume, pitch)

func _physics_process(_delta):
	soundsPlayedThisFrame.clear()

# 2026-11-18 版权清理：16 个 BGM preload 常量（titleBGM/shopBGM/battleBGM 等）
# 及其指向的 HomeBGM.wav / ShopBGM.wav / BattleBGM.wav 已移入隔离区。

class PitchData:
	var lastPlayedTime: float = 0
	var counter = 0

	func play():
		if Util.time <= lastPlayedTime + 0.5:
			if Util.time != lastPlayedTime:
				counter += 1
		else:
			counter = 0

		lastPlayedTime = Util.time

		counter = counter % 16
		var activeCounter
		if counter > 8:
				activeCounter = 16 - counter
		else:
			activeCounter = counter

		var pitch: float = 1 + activeCounter * 0.0625
		return pitch

func pve_bus(stream: AudioStream) -> StringName:
	return load("res://Runtime/Behavior/Utility/SoundBehavior.gd").pve_bus(self, stream)
