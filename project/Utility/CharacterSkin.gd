extends RefCounted
class_name CharacterSkin

var id: int
var order: int
var scene_path: String
var icon_path: String
var hovered_path: String
var _scene: PackedScene
var _icon: Texture2D
var _hovered: Texture2D
var scene: PackedScene:
	get:
		if _scene == null: _scene = AssetStream.resolve(scene_path)
		return _scene
var icon: Texture2D:
	get:
		if _icon == null: _icon = AssetStream.resolve(icon_path)
		return _icon
var icon_hovered: Texture2D:
	get:
		if _hovered == null: _hovered = AssetStream.resolve(hovered_path)
		return _hovered

func release_resources():
	_scene = null
	_icon = null
	_hovered = null

var skinName: String
var prices = [ - 1, - 1, - 1, - 1, - 1]
