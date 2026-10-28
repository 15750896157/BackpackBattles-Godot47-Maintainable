extends Node
var output=""
var checks:Array=[]
var failures:Array=[]
func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func check(value,message):
	checks.append({"ok":bool(value),"message":message})
	if not value:failures.append(message)
func run_tests():
	while not Expedition.initialized:await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(output)
	var holder=Node2D.new();holder.hide();Game.mainNode.add_child(holder)
	for path in ["res://Runtime/Loading/Scenes/CombatBackdrop1.tscn","res://Runtime/Loading/Scenes/CombatBackdrop2.tscn","res://Runtime/Loading/Scenes/CombatBackdrop3.tscn"]:
		check(await AssetStream.prepare([path],"chapter-probe"),path+": chapter background loads")
		var chapter=await AssetStream.instantiate_path(path,"chapter-probe")
		check(is_instance_valid(chapter),path+": chapter scene constructs")
		if is_instance_valid(chapter):
			check(chapter.get_node("Desert").texture!=null and chapter.has_node("BackgroundAnimation"),path+": image and animation dependencies retained")
			chapter.free()
		AssetStream.release("chapter-probe")
	for id in Expedition.bindings.bindings:
		var paths=Expedition.bindings.scene_paths([id])
		check(await AssetStream.prepare(paths,"bound-asset-probe"),id+": asynchronous scene dependencies")
		var item=await Expedition.bindings.instance_async(id,Item.Owner.BuildViewerIcon,"bound-asset-probe")
		check(is_instance_valid(item),id+": scene instantiates")
		if is_instance_valid(item):
			holder.add_child(item);await get_tree().process_frame
			check(is_instance_valid(item.sprite) and item.sprite.texture!=null,id+": visible item texture")
			item.free()
		var image=await Expedition.bindings.texture_async(id)
		check(image!=null and image.get_width()>0,id+": catalog thumbnail")
		AssetStream.release("bound-asset-probe");AssetStream.release("popup")
	AssetStream.release_metadata();holder.queue_free()
	check(Expedition.bindings.errors.is_empty(),"no native asset-binding failures")
	var file=FileAccess.open(output.path_join("bound-assets-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"definitions":Expedition.bindings.bindings.size()},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
