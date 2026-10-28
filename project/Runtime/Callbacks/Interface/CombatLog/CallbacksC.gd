extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCombatLogFilterButtonWithStylebox:
	const Receiver = preload("res://Interface/CombatLog/CombatLogFilterButtonWithStylebox.gd")

	static func updateStyleboxes(subject: Receiver):
		if subject.isPressed:
			subject.set("theme_override_styles/normal", subject.pressedStylebox)
			subject.set("theme_override_styles/hover", subject.hoverPressedStylebox)
			subject.set("theme_override_styles/pressed", subject.hoverPressedStylebox)
			subject.set("theme_override_colors/font_color", subject.pressedFontColor)
			subject.set("theme_override_colors/font_hover_color", subject.pressedFontColor)
			subject.set("theme_override_colors/font_focus_color", subject.pressedFontColor)
			subject.set("theme_override_colors/font_pressed_color", subject.pressedFontColor)
		else:
			subject.set("theme_override_styles/normal", subject.normalStylebox)
			subject.set("theme_override_styles/hover", subject.hoverNormalStylebox)
			subject.set("theme_override_styles/pressed", subject.hoverNormalStylebox)
			subject.set("theme_override_colors/font_color", subject.normalFontColor)
			subject.set("theme_override_colors/font_hover_color", subject.normalFontColor)
			subject.set("theme_override_colors/font_focus_color", subject.normalFontColor)
			subject.set("theme_override_colors/font_pressed_color", subject.normalFontColor)
