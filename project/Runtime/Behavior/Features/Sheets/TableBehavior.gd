extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Sheets/Table.gd")

static func getFlags(subject: Receiver, header: String, enu: Dictionary, line: int):
	var split = subject.getStr(header, line).replace(" ", "").split(",")
	var flags = 0
	for flag in split:
		if flag != "":
			flags += enu[flag]
	return flags

static func getEnu(subject: Receiver, header: String, enu: Dictionary, line: int, default):
	var stringVal = subject.getStr(header, line)
	stringVal = stringVal.replace(" ", "")
	if enu.has(stringVal):
		return enu[stringVal]
	else:
		return default

static func getEnuStuffed(subject: Receiver, header: String, enu: Dictionary, line: int, default):
	var list = subject.getStr(header, line)
	if list == "":
		return default

	var enuVal = 0
	list = list.replace(" ", "")
	for entry in list.split(","):
		assert (enu.has(entry))
		enuVal += enu[entry]

	return enuVal

static func getParamName(subject: Receiver, header: String, line: int, default):
	var entry = subject.getStr(header, line)
	if entry != "":
		var slice = entry.get_slice(":", 1)
		if slice == "":
			print("malformed parameter")
		elif slice != entry:
			return slice
	return default

static func getIntList(subject: Receiver, header: String) -> Array:
	var col = subject.colums[header]
	var ints = []
	ints.resize(col.size())
	for line in col.size():
		ints[line] = int(col[line])
	return ints
