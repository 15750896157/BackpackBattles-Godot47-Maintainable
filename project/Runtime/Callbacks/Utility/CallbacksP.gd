extends RefCounted
## Related leaf callbacks with explicit typed scene receivers.

class ForProfanity:
	const Receiver = preload("res://Utility/Profanity.gd")

	static func flatten(word: String) -> String:
		word = word.to_lower()
		word = word.replace(" ", "")
		word = word.replace(",", "")
		word = word.replace(".", "")
		word = word.replace("'", "")
		word = word.replace("-", "")
		word = word.replace("_", "")
		word = word.replace(";", "")
		word = word.replace(":", "")
		word = word.replace("#", "")
		word = word.replace("3", "e")
		word = word.replace("1", "i")
		word = word.replace("0", "o")
		word = word.replace("4", "a")
		return word
