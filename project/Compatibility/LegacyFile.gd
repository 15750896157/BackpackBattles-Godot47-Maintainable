extends RefCounted
class_name File

const READ = FileAccess.READ
const WRITE = FileAccess.WRITE
const READ_WRITE = FileAccess.READ_WRITE
const WRITE_READ = FileAccess.WRITE_READ
var _file: FileAccess
var endian_swap: bool:
	get: return _file.big_endian if _file else false
	set(value):
		if _file: _file.big_endian = value

func open(path: String, mode: int) -> Error:
	_file = FileAccess.open(path, mode)
	return OK if _file else FileAccess.get_open_error()
func open_encrypted(path: String, mode: int, key: PackedByteArray) -> Error:
	_file = FileAccess.open_encrypted(path, mode, key)
	return OK if _file else FileAccess.get_open_error()
func open_encrypted_with_pass(path: String, mode: int, password: String) -> Error:
	_file = FileAccess.open_encrypted_with_pass(path, mode, password)
	return OK if _file else FileAccess.get_open_error()
func close() -> void:
	if _file: _file.close()
	_file = null
func is_open() -> bool: return _file != null and _file.is_open()
func file_exists(path: String) -> bool: return FileAccess.file_exists(path)
func get_md5(path: String) -> String: return FileAccess.get_md5(path)
func get_sha256(path: String) -> String: return FileAccess.get_sha256(path)
func get_length() -> int: return _file.get_length() if _file else 0
func get_position() -> int: return _file.get_position() if _file else 0
func get_path() -> String: return _file.get_path() if _file else ""
func get_path_absolute() -> String: return _file.get_path_absolute() if _file else ""
func get_error() -> Error: return _file.get_error() if _file else ERR_UNCONFIGURED
func eof_reached() -> bool: return _file.eof_reached() if _file else true
func seek(position: int) -> void:
	if _file: _file.seek(position)
func seek_end(position: int = 0) -> void:
	if _file: _file.seek_end(position)
func get_as_text(skip_cr: bool = false) -> String:
	var text = _file.get_as_text() if _file else ""
	return text.replace("\r", "") if skip_cr else text
func get_line() -> String: return _file.get_line() if _file else ""
func get_csv_line(delimiter: String = ",") -> PackedStringArray: return _file.get_csv_line(delimiter) if _file else PackedStringArray()
func get_buffer(length: int) -> PackedByteArray: return _file.get_buffer(length) if _file else PackedByteArray()
func get_var(allow_objects: bool = false): return _file.get_var(allow_objects) if _file else null
func get_8() -> int: return _file.get_8() if _file else 0
func get_16() -> int: return _file.get_16() if _file else 0
func get_32() -> int: return _file.get_32() if _file else 0
func get_64() -> int: return _file.get_64() if _file else 0
func get_float() -> float: return _file.get_float() if _file else 0.0
func get_double() -> float: return _file.get_double() if _file else 0.0
func get_pascal_string() -> String: return _file.get_pascal_string() if _file else ""
func store_var(value, full_objects: bool = false) -> void:
	if _file: _file.store_var(value, full_objects)
func store_string(value: String) -> void:
	if _file: _file.store_string(value)
func store_line(value: String) -> void:
	if _file: _file.store_line(value)
func store_csv_line(value: PackedStringArray, delimiter: String = ",") -> void:
	if _file: _file.store_csv_line(value, delimiter)
func store_buffer(value: PackedByteArray) -> void:
	if _file: _file.store_buffer(value)
func store_8(value: int) -> void:
	if _file: _file.store_8(value)
func store_16(value: int) -> void:
	if _file: _file.store_16(value)
func store_32(value: int) -> void:
	if _file: _file.store_32(value)
func store_64(value: int) -> void:
	if _file: _file.store_64(value)
func store_float(value: float) -> void:
	if _file: _file.store_float(value)
func store_double(value: float) -> void:
	if _file: _file.store_double(value)
func store_pascal_string(value: String) -> void:
	if _file: _file.store_pascal_string(value)
func flush() -> void:
	if _file: _file.flush()
