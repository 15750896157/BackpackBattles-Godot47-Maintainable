extends FocusGrabbingTextureButton

var skin: CharacterSkin

func setSkin(_skin: CharacterSkin):
	skin = _skin
	texture_normal = skin.icon
	texture_hover = skin.icon_hovered

func onHover():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	super.onHover()
	Game.wardrobe.onSkinIconHovered(self)

func onHoverEnd():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	if isHovered:
		super.onHoverEnd()
		Game.wardrobe.onSkinIconUnhovered(self)

func onPressed():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	super.onPressed()
	Game.wardrobe.onSkinIconSelected(self)
