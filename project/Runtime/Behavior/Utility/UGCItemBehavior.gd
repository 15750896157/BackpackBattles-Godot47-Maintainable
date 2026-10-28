extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/UGCItem.gd")

static func _on_item_created(subject: Receiver, result: int, _file_id: int, _accept_tos: bool) -> void :

	var success = (result == subject.Result.RESULT_OK)

	if success:
		Util.eprint("item created")
		subject.itemId = _file_id
		subject.start_update()
		success = subject.set_metadata(subject.metaDataString)
		if success:
			success = subject.set_visibility(3)
			if success:
				subject.metaDataString = ""
				subject.update()

	else:
		print("item creation failed: ", result)

	if not success:
		subject.queue_free()
		subject.emit_signal("item_creation_failed", result)

static func set_visibility(subject: Receiver, p_visibility: int) -> bool:
	Util.eprint("setting visibility to ", p_visibility)
	var res = Steam.setItemVisibility(subject.updateHandle, p_visibility)
	if not res:
		print("could not set visibility")
	return res

static func _on_item_created_lobbies(subject: Receiver, result: int, _file_id: int, _accept_tos: bool) -> void :
	print("item created - result: ", result)

	subject.itemId = _file_id

	subject.start_update()
	subject.set_title("Title2")
	subject.set_tags(subject.tags)
	subject.set_visibility(0)
	subject.set_metadata("Metadata")
	subject.update()

static func _on_item_updated(subject: Receiver, result: int, _accept_tos: bool) -> void :
	if result == subject.Result.RESULT_OK:

		Util.eprint("item updated")

		subject.emit_signal("item_updated")
	else:
		print("item update failed: ", result)
		subject.emit_signal("item_update_failed", result)

	subject.queue_free()
