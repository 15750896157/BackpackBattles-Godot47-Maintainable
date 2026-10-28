extends Node
signal sw_player_data_received(name, data)
signal sw_player_data_posted(name)
signal sw_player_data_removed(name, data)
var player_name = ""
var player_data = {}
func _store():
	return get_node("/root/LocalServices")
func _later(signal_name, arguments):
	call_deferred("_deliver", signal_name, arguments)
	return self
func _deliver(signal_name, arguments):
	callv("emit_signal", [signal_name] + arguments)
func set_player_data(data):
	player_data = data
func clear_player_data():
	player_data = {}
func get_stats():
	return _store().profile.stats
func get_inventory():
	return player_data.get("inventory", [])
func get_player_data(name):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalPlayersBehavior.gd").get_player_data(self, name)

func post_player_data(name, data, overwrite = true):
	_store().set_player_data(str(name), data, overwrite)
	return _later("sw_player_data_posted", [name])
func delete_all_player_data(name):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalPlayersBehavior.gd").delete_all_player_data(self, name)

func delete_player_data(name, data):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalPlayersBehavior.gd").delete_player_data(self, name, data)

func delete_player_weapons(name):
	return delete_player_data(name, {"weapons": null})
func remove_player_money(name):
	return delete_player_data(name, {"money": null})
func delete_player_items(name, item_name):
	return delete_player_data(name, {str(item_name): null})
