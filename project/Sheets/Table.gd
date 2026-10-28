extends RefCounted
class_name Table

var colums = Dictionary()

func loadFromCsv(filepath: String, key = null):
	return load("res://Runtime/Behavior/Sheets/TableBehavior.gd").loadFromCsv(self, filepath, key)

func isEqual(header: String, line: int, to):

	return colums[header][line] == to

func getStr(header: String, line: int):
	return colums[header][line]

func getFlags(header: String, enu: Dictionary, line: int):
	return load("res://Runtime/Behavior/Features/Sheets/TableBehavior.gd").getFlags(self, header, enu, line)

func getEnu(header: String, enu: Dictionary, line: int, default = null):
	return load("res://Runtime/Behavior/Features/Sheets/TableBehavior.gd").getEnu(self, header, enu, line, default)

func getEnuStuffed(header: String, enu: Dictionary, line: int, default = null):
	return load("res://Runtime/Behavior/Features/Sheets/TableBehavior.gd").getEnuStuffed(self, header, enu, line, default)

func getInt(header: String, line: int, default = null):
	var entry = getStr(header, line)
	if entry == "":
		return default
	else:
		return int(entry)

func getFloat(header: String, line: int, default = null):
	var entry = getStr(header, line)
	if entry == "":
		return default
	else:
		return float(entry)

func getParamName(header: String, line: int, default = ""):
	return load("res://Runtime/Behavior/Features/Sheets/TableBehavior.gd").getParamName(self, header, line, default)

func fill(owner: Object, attribute: String, line: int):
	return load("res://Runtime/Behavior/Sheets/TableBehavior.gd").fill(self, owner, attribute, line)

func fillList(owner: Object, attributeList: Array, line: int):
	for attribute in attributeList:
		fill(owner, attribute, line)

func getHeaders():
	return colums.keys()

func countRows():
	return colums.values()[0].size()

func getIntList(header: String) -> Array:
	return load("res://Runtime/Behavior/Features/Sheets/TableBehavior.gd").getIntList(self, header)

