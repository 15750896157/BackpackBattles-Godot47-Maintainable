extends RefCounted

const MAX_RUNS = 1000
const LocalHistoryStore = preload("res://Utility/LocalHistoryStore.gd")
const db_name = "user://local_history.json"
const verbose = false

# Kept for diagnostics; this is a native file store, with no GDNative DLL.
var db
var last_error: String = ""

func _init(storage_path: String = db_name, connect_events: bool = true):
	db = LocalHistoryStore.new(storage_path)
	if connect_events:
		Game.connect("fresh_run_started", Callable(self, "addRunEntry"))
		Game.connect("round_result", Callable(self, "addRoundEntry"))
		Game.connect("special_item_bought", Callable(self, "onSpecialItemBought"))
	if db.recovery_message != "":
		push_warning(db.recovery_message)
	_report_storage_result(db.last_error == "")

func verifyTables() -> bool:
	return db.verify()

func createTables():
	return _report_storage_result(db.reset())

func addRunEntry():
	return load("res://Runtime/Behavior/Utility/BuildHistoryDBBehavior.gd").addRunEntry(self)

func onSpecialItemBought(item):
	return load("res://Runtime/Behavior/Utility/BuildHistoryDBBehavior.gd").onSpecialItemBought(self, item)

func addRoundEntry():
	return load("res://Runtime/Behavior/Utility/BuildHistoryDBBehavior.gd").addRoundEntry(self)

func addRunResult():
	# The original UI derives the final run outcome from its round entries.
	return true

func readRunHistory() -> Dictionary:
	return load("res://Runtime/Behavior/Utility/BuildHistoryDBBehavior.gd").readRunHistory(self)

func cleanup():
	# Delete old rounds together with their parent run; retain at most MAX_RUNS.
	var minimum_run_id = maxi(0, Game.getNumStartedRuns() - MAX_RUNS + 1)
	return _report_storage_result(db.prune(MAX_RUNS, minimum_run_id))

func _report_storage_result(success: bool) -> bool:
	last_error = db.last_error
	if not success:
		push_error("Local battle history: " + last_error)
	return success
