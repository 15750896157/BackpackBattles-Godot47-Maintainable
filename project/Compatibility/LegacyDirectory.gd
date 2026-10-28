extends RefCounted
class_name LegacyDirectory

var _directory: DirAccess = DirAccess.open("res://")
func open(path: String) -> Error:
	_directory = DirAccess.open(path)
	return OK if _directory else DirAccess.get_open_error()
func change_dir(path: String) -> Error: return _directory.change_dir(path) if _directory else ERR_UNCONFIGURED
func get_current_dir() -> String: return _directory.get_current_dir() if _directory else "res://"
func file_exists(path: String) -> bool: return FileAccess.file_exists(ProjectSettings.globalize_path(path)) if path.is_absolute_path() else _directory.file_exists(path)
func dir_exists(path: String) -> bool: return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)) if path.is_absolute_path() else _directory.dir_exists(path)
func make_dir(path: String) -> Error: return DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path)) if path.is_absolute_path() else _directory.make_dir(path)
func make_dir_recursive(path: String) -> Error:
	return load("res://Runtime/Callbacks/Compatibility/CallbacksL.gd").ForLegacyDirectory.make_dir_recursive(self, path)

func rename(from: String, to: String) -> Error:
	return load("res://Runtime/Callbacks/Compatibility/CallbacksL.gd").ForLegacyDirectory.rename(self, from, to)

func copy(from: String, to: String) -> Error:
	return load("res://Runtime/Callbacks/Compatibility/CallbacksL.gd").ForLegacyDirectory.copy(self, from, to)

func remove(path: String) -> Error: return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) if path.is_absolute_path() else _directory.remove(path)
func list_dir_begin(skip_navigational: bool = true, skip_hidden: bool = true) -> Error:
	if not _directory: return ERR_UNCONFIGURED
	_directory.include_navigational = not skip_navigational
	_directory.include_hidden = not skip_hidden
	return _directory.list_dir_begin()
func get_next() -> String: return _directory.get_next() if _directory else ""
func current_is_dir() -> bool: return _directory.current_is_dir() if _directory else false
func list_dir_end() -> void:
	if _directory: _directory.list_dir_end()
