extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Sheets/Table.gd")

static func loadFromCsv(subject: Receiver, filepath: String, key):
	var file = File.new()
	if key != null:
		file.open_encrypted(filepath, file.READ, key)
	else:
		file.open(filepath, file.READ)

	var header = file.get_csv_line()

	for entry in header:
		subject.colums[entry] = []

	var headerArr = subject.colums.keys()

	while not file.eof_reached():
		var line = file.get_csv_line()
		for i in line.size():
			var relevantHeader = headerArr[i]

			subject.colums[relevantHeader].append(line[i])

	file.close()
	return subject

static func fill(subject: Receiver, owner: Object, attribute: String, line: int):
	var sheetVariable = subject.colums[attribute][line]
	if sheetVariable == "":
		return
	var owner_variable = owner.get(attribute)
	if typeof(owner_variable) == TYPE_INT:
		owner.set(attribute, int(sheetVariable))
	elif typeof(owner_variable) == TYPE_FLOAT:
		owner.set(attribute, float(sheetVariable))
	elif typeof(owner_variable) == TYPE_STRING:
		owner.set(attribute, sheetVariable)
