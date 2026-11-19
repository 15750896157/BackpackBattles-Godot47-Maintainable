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
		if _icon == null: _icon = AssetStream.resolve(preview_icon_path())
		return _icon
var icon_hovered: Texture2D:
	get:
		if _hovered == null: _hovered = AssetStream.resolve(preview_hovered_path())
		return _hovered

func release_resources():
	_scene = null
	_icon = null
	_hovered = null

func preview_icon_path() -> String:
	if ResourceLoader.exists(icon_path, "Texture2D"):
		return icon_path
	var body := scene_path.get_base_dir().path_join("Body.png")
	return body if ResourceLoader.exists(body, "Texture2D") else ""

func preview_hovered_path() -> String:
	return hovered_path if ResourceLoader.exists(hovered_path, "Texture2D") else preview_icon_path()

var skinName: String
var prices = [ - 1, - 1, - 1, - 1, - 1]
