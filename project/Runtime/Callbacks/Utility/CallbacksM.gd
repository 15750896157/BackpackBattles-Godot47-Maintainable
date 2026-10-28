extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForMaterialCompiler:
	const Receiver = preload("res://Utility/MaterialCompiler.gd")

	static func _ready(subject: Receiver):
		if Expedition.enabled:
			# Compile only materials reached by actual views; no project-wide GPU warmup.
			await subject.get_tree().process_frame
			subject.completed = true
			subject.finished_loading_materials.emit()
			return

		var counter = 0
		var dir = LegacyDirectory.new()
		var directories = []
		var files = []
		if dir.open("res://") == OK:
			dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
			Util.addDirectoryContents(dir, files, directories)

			for fileName in files:
				if fileName.ends_with("Particles.material"):

					var sprite = Sprite2D.new()
					sprite.texture = subject.pixel_tex
					subject.add_child(sprite)

					sprite.position = Vector2(500, 500)
					sprite.set_material(load(fileName))
					counter += 1

				elif fileName.ends_with(".material"):

					var particles = GPUParticles2D.new()
					particles.texture = subject.pixel_tex
					particles.position = Vector2(1000, 500)
					subject.add_child(particles)
					particles.set_process_material(load(fileName))
					counter += 1

				if counter > 10:
					counter = 0

		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		await subject.get_tree().process_frame
		subject.queue_free()
		subject.emit_signal("finished_loading_materials")

class ForMerchButton:
	const Receiver = preload("res://Utility/MerchButton.gd")

	static func _ready(subject: Receiver):
		var releaseTime = Time.get_unix_time_from_datetime_string("2024-09-06 03:00:00.000")

		var curTime = Time.get_unix_time_from_system()
		var timeDif = releaseTime - curTime
		if timeDif < 0:
			subject.queue_free()
			return

		var timeInDays: float = timeDif / (60 * 60 * 24)
		var daysToRelease = int(timeInDays)
		var hoursToRelease = int((timeInDays - daysToRelease) * 24)

		var format = "[center]{days}d {hours}h"
		subject.timeLeftLabel.text = format.format({"days": daysToRelease, "hours": hoursToRelease})

		subject.linkButton.connect("mouse_entered", Callable(subject, "onHover"))
		subject.linkButton.connect("mouse_exited", Callable(subject, "onHoverEnd"))
		subject.openButton.connect("pressed", Callable(subject, "open"))
		subject.closeButton.connect("pressed", Callable(subject, "close"))
		if Game.getConfigValue("Options", "hide_ranger_plushie", false):
			subject.close(false)
		else:
			subject.open(false)

class ForMultiTimer:
	const Receiver = preload("res://Utility/MultiTimer.gd")

	static func onTimeout(subject: Receiver):
		subject.emit_signal("multi_timeout")

		if not subject.isFinished():
			var nextTimestamp = subject.timestamps.pop_front()
			var dif = nextTimestamp - Util.time
			if dif > 0.05:
				subject.start(dif)
			else:
				subject.onTimeout()
