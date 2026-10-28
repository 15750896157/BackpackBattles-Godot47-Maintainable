extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForInputMapping:
	const Receiver = preload("res://Interface/Options/InputMapping.gd")

	static func _ready(subject: Receiver):
		for action in InputMap.get_actions():
			subject.defaultInputMappings[action] = InputMap.action_get_events(action)

		if ResourceLoader.exists("res://PvE/NativePreferences.gd"): return
		var config = ConfigFile.new()
		var err = config.load(Game.getLoadPath(Game.config_format))

		if config.has_section("Input"):
			var inputActions = config.get_section_keys("Input")
			for mappedAction in inputActions:
				var index = 0
				var actionName = mappedAction
				if mappedAction.ends_with("_1"):
					index = 0
					actionName = mappedAction.trim_suffix("_1")
				elif mappedAction.ends_with("_2"):
					index = 1
					actionName = mappedAction.trim_suffix("_2")

				InputMap.action_erase_events(actionName)
				if index == 1 and subject.defaultInputMappings[actionName].size() > 0:
					InputMap.action_add_event(actionName, subject.defaultInputMappings[actionName][0])

				var configValue = config.get_value("Input", mappedAction)
				if configValue in Util.mouseButtonsInverted:
					var inputEvent = InputEventMouseButton.new()
					inputEvent.set_button_index(Util.mouseButtonsInverted[configValue])
					InputMap.action_add_event(actionName, inputEvent)

				elif typeof(configValue) == TYPE_INT:
					var inputEvent = InputEventJoypadButton.new()
					inputEvent.set_button_index(int(configValue))
					InputMap.action_add_event(actionName, inputEvent)

				else:
					var inputEvent = InputEventKey.new()
					inputEvent.set_keycode(OS.find_keycode_from_string(configValue))
					InputMap.action_add_event(actionName, inputEvent)

				if index == 0:
					for i in range(1, subject.defaultInputMappings[actionName].size()):
						InputMap.action_add_event(actionName, subject.defaultInputMappings[actionName][i])
