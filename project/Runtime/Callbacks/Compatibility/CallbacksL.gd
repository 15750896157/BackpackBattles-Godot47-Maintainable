extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForLegacyDirectory:
	const Receiver = preload("res://Compatibility/LegacyDirectory.gd")

	static func make_dir_recursive(subject: Receiver, path: String) -> Error: return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) if path.begins_with("user://") or path.begins_with("res://") or path.is_absolute_path() else subject._directory.make_dir_recursive(path)

	static func rename(subject: Receiver, from: String, to: String) -> Error: return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) if from.is_absolute_path() else subject._directory.rename(from, to)

	static func copy(subject: Receiver, from: String, to: String) -> Error: return DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)) if from.is_absolute_path() else subject._directory.copy(from, to)
