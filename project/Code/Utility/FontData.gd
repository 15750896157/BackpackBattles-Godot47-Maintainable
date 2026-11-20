extends RefCounted
class_name FontData

var font = null
var size
var spaceTop
var spaceBottom

var bold_font = null
var bold_size
var bold_spaceTop
var bold_spaceBottom

var curLocale = ""

func setFont(normalFont: LegacyFont) -> void :
	if normalFont:
		font = normalFont.font_data
		size = normalFont.size
		spaceTop = normalFont.spacing_top
		spaceBottom = normalFont.spacing_bottom

func setBoldFont(boldFont: LegacyFont) -> void :
	if boldFont:
		bold_font = boldFont.font_data
		bold_size = boldFont.size
		bold_spaceTop = boldFont.spacing_top
		bold_spaceBottom = boldFont.spacing_bottom

func applyToFont(normalFont: LegacyFont) -> void :
	normalFont.font_data = font
	normalFont.size = size
	normalFont.spacing_top = spaceTop
	normalFont.spacing_bottom = spaceBottom

func applyToBoldFont(boldFont: LegacyFont) -> void :
	boldFont.font_data = bold_font
	boldFont.size = bold_size
	boldFont.spacing_top = bold_spaceTop
	boldFont.spacing_bottom = bold_spaceBottom
