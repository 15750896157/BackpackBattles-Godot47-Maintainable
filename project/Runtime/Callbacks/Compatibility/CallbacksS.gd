extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForShaderClock:
	const Receiver = preload("res://Compatibility/ShaderClock.gd")

	static func _process(subject: Receiver, _delta: float) -> void:
		var now = Time.get_ticks_usec()
		subject._elapsed += float(now - subject._last_tick) / 1000000.0 * subject._scale
		subject._last_tick = now
		RenderingServer.global_shader_parameter_set("bb_shader_time", subject._elapsed)
