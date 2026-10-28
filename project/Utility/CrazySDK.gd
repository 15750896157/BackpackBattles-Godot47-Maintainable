extends Node
## Local replacement for web advertising/gameplay callbacks.
signal ad_started
signal ad_finished
signal ad_error(error)
signal ad_done
func hasSDK() -> bool: return true
func _record(event: String) -> void:
	load("res://Runtime/Callbacks/Utility/CallbacksC.gd").ForCrazySDK._record(self, event)

func midgameAd() -> void: _local_ad("midgame")
func rewardedAd() -> void: _local_ad("rewarded")
func _local_ad(kind: String) -> void:
	_record("local_" + kind)
	ad_started.emit()
	_finish_ad.call_deferred()
func _finish_ad() -> void:
	ad_finished.emit()
	ad_done.emit()
func adStarted(_args = null) -> void: ad_started.emit()
func adError(error) -> void:
	ad_error.emit(error)
	ad_done.emit()
func adFinished(_args = null) -> void: _finish_ad()
func gameplayStart() -> void: _record("gameplay_start")
func gameplayStop() -> void: _record("gameplay_stop")
func happytime() -> void: _record("happytime")
