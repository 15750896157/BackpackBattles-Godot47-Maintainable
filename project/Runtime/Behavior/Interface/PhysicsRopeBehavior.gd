extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/PhysicsRope.gd")

static func _ready(subject: Receiver):
	Game.connect("switch_to_shop", Callable(subject, "onSwitchToShop"))
	InputBlocker.connect("inputs_blocked", Callable(subject, "endDrag"))

	subject.ropeHolder.position = Vector2(0, 0)

	for i in subject.NUM_SEGMENTS:
		var segment = subject.segmentScene.instantiate()
		if subject.curEndY > 300.0:
			segment.LENGTH = 30
		else:
			segment.LENGTH = 60

		subject.addSegment(segment)

	Util.reparentNode(subject.tag, subject.segments[ - 3])
	subject.tag.position = Vector2.ZERO

	subject.addSegment(subject.ropeEndSegment)

	for i in subject.NUM_SEGMENTS:
		var joint: PinJoint2D = PinJoint2D.new()

		if i == 0:
			joint.node_a = subject.ropeHolder.get_path()
		else:
			joint.node_a = subject.segments[i - 1].get_path()

		joint.node_b = subject.segments[i].get_path()
		joint.position = subject.segments[i].getStartPos()
		joint.softness = 0.2

		subject.add_child(joint)
		subject.joints.push_back(joint)

	var endJoint = PinJoint2D.new()
	endJoint.node_a = subject.segments[ - 1].get_path()
	endJoint.node_b = subject.ropeEndSegment.get_path()
	endJoint.position = subject.ropeEndSegment.getStartPos()
	endJoint.softness = 0.1
	subject.add_child(endJoint)
	subject.joints.push_back(endJoint)

	subject.segments.push_back(subject.ropeEndSegment)

	subject.jointPositionNodes.push_back(subject.ropeHolder)
	for segment in subject.segments:
		subject.jointPositionNodes.push_back(segment.end)

	for joint in subject.joints:
		subject.jointPositions.push_back(joint.position)

static func addSegment(subject: Receiver, segment):
	if not segment.is_inside_tree():
		subject.add_child(segment)
		subject.segments.push_back(segment)
	segment.position = Vector2(0, subject.curEndY + segment.getLength() * 0.5)
	subject.curEndY += segment.getLength()
	segment.rope = subject
	segment.clickArea.connect("gui_input", Callable(subject, "gui_input_segment").bind(segment))

static func _physics_process(subject: Receiver, delta):

	var difToStart = subject.segments[ - 1].global_position.distance_to(subject.ropeHolder.global_position)
	if difToStart > 1000:
		print("Reroll rope reset ", difToStart)
		subject.reset()
		return

	subject.line2D.clear_points()
	var points = []
	for segment in subject.jointPositionNodes:
		points.push_back(segment.global_position - subject.global_position)

	var smoothed = subject.catmull_rom_spline(points, 10)
	smoothed.reverse()
	for point in smoothed:
		subject.line2D.add_point(point)

	if subject.draggedSegment != null:

		var clampedMousePos = subject.getClampedMousePos()
		var pull = Util.getMousePosInWindow().y - clampedMousePos.y

		if pull > 0:
			subject.pulledY = min(subject.MAX_PULL, subject.pulledY + pull)
			if subject.pulledY == subject.MAX_PULL:
				subject.rerollReadyTime = Util.time + 0.2
				subject.endDrag()
				subject.emit_signal("reroll")
		else:
			subject.pulledY = max(0, subject.pulledY - subject.PULL_UP_SPEED)
	else:
		subject.pulledY = max(0, subject.pulledY - subject.PULL_UP_SPEED)

	subject.ropeHolder.position.y = subject.pulledY

static func gui_input_segment(subject: Receiver, event, segment):
	if subject.rerollReadyTime > Util.time:
		return

	if Util.isClickEvent(event):
		if (Game.isShopActive() and
			not Game.draggedItem and
			Util.time > Game.lastItemDropTime + 0.5):

			subject.draggedSegment = segment
			subject.draggedSegment.startDrag()
			Game.cancelSwitch()

	elif Util.isClickReleaseEvent(event):
		subject.endDrag()

	elif Util.isRightClick(event):
		Game.rerollRope.switchToStiffRope()
		subject.rerollReadyTime = Util.time + 0.2

static func catmull_rom_spline(subject: Receiver, _points: Array, resolution: int, extrapolate_end_points) -> Array:

	var points = _points.duplicate()
	if extrapolate_end_points:
		points.insert(0, points[0] - (points[1] - points[0]))
		points.append(points[ - 1] + (points[ - 1] - points[ - 2]))

	var smooth_points = Array()
	if points.size() < 4:
		return points

	for i in range(1, points.size() - 2):
		var p0 = points[i - 1]
		var p1 = points[i]
		var p2 = points[i + 1]
		var p3 = points[i + 2]

		for t in range(0, resolution):
			var tt = t / float(resolution)
			var tt2 = tt * tt
			var tt3 = tt2 * tt
			var q = (0.5 * (
				(2.0 * p1)
				+ ( - p0 + p2) * tt
				+ (2.0 * p0 - 5.0 * p1 + 4 * p2 - p3) * tt2
				+ ( - p0 + 3.0 * p1 - 3.0 * p2 + p3) * tt3
			))

			smooth_points.append(q)

	return smooth_points

static func getClampedMousePos(subject: Receiver) -> Vector2:
	var draggedSegmentIndex = subject.segments.find(subject.draggedSegment)
	var length = 20
	for i in draggedSegmentIndex + 1:
		length += subject.segments[i].getLength()

	var ropeHolderToMouse = Util.getMousePosInWindow() - subject.ropeHolder.global_position

	return subject.ropeHolder.global_position + ropeHolderToMouse.limit_length(length)
