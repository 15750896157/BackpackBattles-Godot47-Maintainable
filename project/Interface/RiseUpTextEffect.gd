@tool
extends RichTextEffect

const displacementCurve = preload("res://Interface/LetterDisplacementCurve.tres")
const OFFSET = 50.0

var bbcode = "riseup"

var dict = {1: {}, 2: {}, 3: {}}

func _process_custom_fx(char_fx: CharFXTransform):
	var labelId = int(char_fx.env.get("id", 1))
	var timesDict = dict[labelId]

	if char_fx.visible:
		if not char_fx.range.x in timesDict:
			timesDict[char_fx.range.x] = char_fx.elapsed_time

		var timePassed = char_fx.elapsed_time - timesDict[char_fx.range.x]
		var curveVal = displacementCurve.sample(timePassed * 4.0)
		char_fx.offset.y += curveVal * OFFSET
		char_fx.color.a = 1.0 - curveVal

	else:
		timesDict.erase(char_fx.range.x)

	return true
