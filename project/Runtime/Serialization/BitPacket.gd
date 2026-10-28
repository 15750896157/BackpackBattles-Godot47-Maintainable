extends RefCounted
## Bit-order and the 62-based six-bit alphabet are persisted legacy formats.

var bits: Array = []
var currentBit = 0
var last_bit: int = 0
const BASE64OFFSET = 62

static func binaryCeil(number):
	return pow(2, ceil(log(number) / log(2)))

func clear():
	bits.clear()
	currentBit = 0
	last_bit = 0

func bitsLeft():
	return bits.size() - currentBit

func pushBit(value: int):
	bits.append(mini(value, 1))
	last_bit += 1

func pushBitsize(value: int, width: int):
	for offset in width:
		# Mask before normalizing: signed bit 63 has a persisted legacy encoding.
		pushBit(value & (1 << (width - offset - 1)))

func pullBitsize(width: int) -> int:
	var result = 0
	for offset in width:
		if currentBit == last_bit:
			return -1
		result = (result << 1) + int(bits[currentBit])
		currentBit += 1
	return result

func push(value: int, range_max: int):
	if Game.EDITOR:
		assert(value < range_max)
	pushBitsize(value, int(ceil(log(range_max) / log(2))))

func pull(range_max: int) -> int:
	return pullBitsize(int(ceil(log(range_max) / log(2))))

func _pack(width: int, offset: int = 0) -> PackedByteArray:
	var packed = PackedByteArray()
	for first in range(0, bits.size(), width):
		var value = 0
		for digit in width:
			var index = first + digit
			value = (value << 1) + (int(bits[index]) if index < bits.size() else 0)
		packed.append(value + offset)
	return packed

func _append_word(value: int, width: int):
	pushBitsize(value, width)

func toByteArray():
	return _pack(8)

func fromByteArray(bytes: PackedByteArray):
	# Existing callers explicitly reset the read cursor; only payload is replaced.
	bits.clear()
	last_bit = 0
	for byte in bytes:
		_append_word(byte, 8)
	return self

func toGodotString() -> String:
	return _pack(6, BASE64OFFSET).get_string_from_ascii()

func fromGodotString(encoded: String):
	for byte in encoded.to_ascii_buffer():
		var word = byte - BASE64OFFSET
		if word < 0 or word > 63:
			return false
		_append_word(word, 6)
	return true

func toGodotString_legacy() -> String:
	var result = ""
	for byte in toByteArray():
		result += String.chr(byte + 65)
	return result

func fromGodotString_legacy(encoded: String):
	var bytes = PackedByteArray()
	for character in encoded:
		bytes.append(character.unicode_at(0) - 65)
	fromByteArray(bytes)

func serializeInt(value: int, width: int = 64) -> String:
	return serializeIntArray([value], width)

func serializeIntArray(values: Array, width: int = 64) -> String:
	clear()
	for value in values:
		pushBitsize(value, width)
	return toGodotString()

func deserializeInt(encoded: String, width: int = 64) -> int:
	clear()
	fromGodotString(encoded)
	return pullBitsize(width)

func deserializeIntArray(encoded: String, width: int = 64) -> Array:
	clear()
	fromGodotString(encoded)
	# Preserve the existing encoded-character count contract, including exhaustion.
	var result: Array = []
	for index in encoded.length():
		result.append(pullBitsize(width))
	return result

func serializeString(value: String) -> String:
	clear()
	fromByteArray(value.to_utf8_buffer())
	return toGodotString()

func deserializeString(encoded: String) -> String:
	clear()
	fromGodotString(encoded)
	var bytes = PackedByteArray()
	for index in bits.size() / 8:
		bytes.append(pullBitsize(8))
	return bytes.get_string_from_utf8()

func pprint():
	return "".join(bits.map(func(bit): return str(bit)))

func fromString(value):
	bits.clear()
	last_bit = 0
	for character in value:
		pushBit(int(character == "1"))

func toUtf8() -> String:
	# Compatibility for the old diagnostic API, including its temporary file.
	var file = File.new()
	file.open("user://score.dat", File.WRITE_READ)
	file.store_buffer(toByteArray())
	var text = file.get_as_text(false)
	file.close()
	print("utf8: ", text)
	return text

func fromUtf8(value: String):
	fromByteArray(value.to_utf8_buffer())
	print("num bits after conversion: ", bits.size())

func toAsciiString() -> String:
	var bytes = toByteArray()
	print("num bits before conversion: ", bits.size())
	print(bytes)
	return bytes.get_string_from_ascii()

func fromAsciiString(value: String):
	var bytes = value.to_ascii_buffer()
	print("ascii: ", value)
	print("converted byte array: ", bytes)
	fromByteArray(bytes)
	print("num bits after conversion: ", bits.size())
