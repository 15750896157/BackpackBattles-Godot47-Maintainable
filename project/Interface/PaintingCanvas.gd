extends TextureButton

@export var paintColor = Color(1.2, 1.6, 1.7)

var grabbed = false

var image: Image
var imageTexture: ImageTexture

var bounds = Rect2(0, 0, 630, 350)
var lastPos: Vector2

func _ready():
	connect("button_down", Callable(self, "_button_down"))
	connect("button_up", Callable(self, "_button_up"))
	image = Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	imageTexture = ImageTexture.create_from_image(image)
	texture_normal = imageTexture

func _button_down():
	if not Game.draggedItem:
		lastPos = get_global_mouse_position() - global_position
		lastPos /= scale
		grabbed = true

func _button_up():
	grabbed = false

func _physics_process(delta):
	if grabbed:
		var localPos = get_global_mouse_position() - global_position
		localPos /= scale

		for i in 5:
			var point = localPos + Util.randInCircle(1)
			if bounds.has_point(point):
				image.set_pixelv(Vector2i(point), paintColor)

		var distToLastPoint = (localPos - lastPos).length()
		for i in int(distToLastPoint):
			var point = lerp(lastPos, localPos, i / distToLastPoint)
			if bounds.has_point(point):
				image.set_pixelv(Vector2i(point), paintColor)

		imageTexture.update(image)
		texture_normal = imageTexture
		lastPos = localPos
