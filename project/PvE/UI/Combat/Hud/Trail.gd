extends Line2D

var tween: Tween
@export var length = 30
@export var active = false
@onready var trailPosition = get_parent()

func _ready():
	set_as_top_level(true)
	scale = Vector2(1, 1)
	clear_points()
	modulate = Color.TRANSPARENT

	if active:
		activate()

func _physics_process(delta):
	if active:
		add_point(trailPosition.global_position)

		if points.size() > length:
			remove_point(0)

func activate():
	clear_points()
	active = true
	modulate = Color.WHITE
	if tween != null and tween.is_valid():
		tween.kill()

func stop(free: bool = false):
	active = false
	if tween != null and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	if free:
		tween.tween_callback(queue_free)
