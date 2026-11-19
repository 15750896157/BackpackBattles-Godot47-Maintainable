extends RefCounted
## One supplied hand, rendered as cursor states. No legacy glove images.
const PATH="res://Art/Supplied20261102/ui/ui_hand_hint.png"
static func images()->Array:
	var source:Image=load(PATH).get_image()
	source.resize(48,49,Image.INTERPOLATE_LANCZOS)
	var result:Array=[]
	for index in 6:
		var image=source.duplicate()
		if index%2==1:image.adjust_bcs(0.82,1.0,1.0)
		result.append(image)
	return result
