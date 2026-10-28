extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Compatibility/LegacyTween.gd")

static func interpolate_property(subject: Receiver, object: Object, property: NodePath, initial_value, final_value, duration: float, transition: int, ease: int, delay: float) -> bool:
	subject._jobs.append({"object": object, "property": String(property).replace("shader_param/", "shader_parameter/"), "initial": initial_value, "final": final_value, "duration": duration, "transition": transition, "ease": ease, "delay": delay})
	return true

static func start(subject: Receiver) -> bool:
	subject.stop_all()
	subject._tween = subject.create_tween().set_parallel(true).set_speed_scale(subject.playback_speed)
	for job in subject._jobs:
		if not is_instance_valid(job.object): continue
		var tweener: Tweener
		if job.has("property"):
			var value = subject._tween.tween_property(job.object, job.property, job.final, job.duration)
			if job.initial != null: value.from(job.initial)
			tweener = value.set_trans(job.transition).set_ease(job.ease).set_delay(job.delay)
		else:
			tweener = subject._tween.tween_method(Callable(job.object, job.method), job.initial, job.final, job.duration).set_trans(job.transition).set_ease(job.ease).set_delay(job.delay)
		subject._tween.tween_callback(func(): subject.tween_completed.emit(job.object, NodePath(job.get("property", job.get("method", ""))))).set_delay(job.delay + job.duration)
	subject._tween.finished.connect(func(): subject.tween_all_completed.emit())
	return true

static func interpolate_method(subject: Receiver, object: Object, method: String, initial_value, final_value, duration: float, transition: int, ease: int, delay: float) -> bool:
	subject._jobs.append({"object": object, "method": method, "initial": initial_value, "final": final_value, "duration": duration, "transition": transition, "ease": ease, "delay": delay})
	return true
