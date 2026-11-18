extends CanvasLayer
## Shared startup/scene loading feedback, always above the cloud curtain.
const REF=preload("res://PvE/UI/ReferenceCanvas.gd")
var root:Control
var bar:TextureProgressBar
var marker:TextureRect
var background:TextureRect
var generation=0
var requested_at_start=0
var loaded_at_start=0
var mode=""
var closing=false
var capturing_startup=false
var history:Array=[]
var progress_target=0.0
const BAR_KEYS=["loading_base","loading_fill","loading_icon"]
const BACKGROUNDS=["loading_camp","loading_0","loading_1","loading_2","loading_3","loading_5","loading_6"]
func _init():
	layer=950;process_mode=Node.PROCESS_MODE_ALWAYS
func present():
	var index := int(Time.get_ticks_usec() % BACKGROUNDS.size())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-loading-index="):index=clampi(int(arg.trim_prefix("--qa-loading-index=")),0,BACKGROUNDS.size()-1)
	var backdrop: String = BACKGROUNDS[index]
	if not await AssetStream.prepare(REF.paths([backdrop]+BAR_KEYS),"loading-ui"):return
	root=Control.new();root.size=Vector2(1920,1080);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	background=REF.picture(root,backdrop,Rect2(0,0,1920,1080),true)
	REF.picture(root,"loading_base",Rect2(355,941,1209,77),true)
	bar=TextureProgressBar.new();bar.position=Vector2(359,946);bar.size=Vector2(1201,68);bar.nine_patch_stretch=true
	bar.texture_progress=REF.texture("loading_fill");bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(bar)
	marker=REF.picture(root,"loading_icon",Rect2(360,929,146,104))
	_start("startup")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-startup-image="):
			capturing_startup=true;bar.value=0;marker.position.x=359-73
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--qa-startup-image="))
			capturing_startup=false
			break
func _start(reason:String):
	generation+=1;mode=reason;closing=false
	requested_at_start=int(AssetStream.metrics.requested);loaded_at_start=int(AssetStream.metrics.loaded)
	bar.value=0;marker.position.x=359-73
	progress_target=0.0
	root.modulate=Color.WHITE;root.show();show()
	background.visible=reason=="startup"
	set_process(true)
	history.append({"event":"begin","reason":reason,"ticket":generation,"layer":layer})
func _request_current(current:Callable)->bool:
	return current.is_null() or (current.is_valid() and bool(current.call()))
func begin_scene(reason:String,current:Callable=Callable())->int:
	while not is_instance_valid(root) and not AssetStream.stopping:
		if not _request_current(current):return -1
		await get_tree().process_frame
	if AssetStream.stopping or not _request_current(current):return -1
	_start(reason)
	return generation
func _process(delta):
	if not is_instance_valid(root) or closing or capturing_startup:return
	var requested=maxi(1,int(AssetStream.metrics.requested)-requested_at_start)
	var completed=maxi(0,int(AssetStream.metrics.loaded)-loaded_at_start)
	# IO supplies the first 85%; the final phase waits for construction and reveal.
	progress_target=maxf(progress_target,minf(94.0,85.0*completed/requested))
	bar.value=move_toward(bar.value,progress_target,delta*180.0)
	marker.position.x=359+1201*bar.value/100.0-73
	var idle=AssetStream.pending.is_empty() and AssetStream.inflight.is_empty() and AssetStream.jobs.is_empty()
	if mode=="startup" and idle and Expedition.initialized and Expedition.art!=null and Expedition.art.ready_kind=="title":finish(generation)
func finish(ticket:int=-1):
	if not is_instance_valid(root) or closing or (ticket>=0 and ticket!=generation):return
	var expected=generation;closing=true
	var initial=bar.value
	history.append({"event":"ready","reason":mode,"ticket":expected,"value":100.0})
	var reduced=Expedition.preferences!=null and Expedition.preferences.values.reduce_motion
	var fill_duration=0.04 if reduced else 0.10
	var fade_duration=0.08 if reduced else 0.14
	var duration=fill_duration+fade_duration
	var elapsed=0.0;var previous=Time.get_ticks_usec()
	while elapsed<duration and expected==generation and not AssetStream.stopping:
		await get_tree().process_frame
		if expected!=generation or AssetStream.stopping:return
		var now=Time.get_ticks_usec();elapsed+=minf(0.05,float(now-previous)/1000000.0);previous=now
		bar.value=lerpf(initial,100.0,clampf(elapsed/fill_duration,0.0,1.0))
		marker.position.x=359+1201*bar.value/100.0-73
		root.modulate.a=1.0-clampf((elapsed-fill_duration)/fade_duration,0.0,1.0)
	if expected!=generation:return
	root.hide();hide();set_process(false);closing=false
	background.texture=null
	AssetStream.hold(REF.paths(BAR_KEYS),"loading-ui")
	history.append({"event":"hidden","reason":mode,"ticket":expected})
	mode=""
func cancel(ticket:int):
	if ticket<0 or ticket!=generation:return
	var reason=mode
	generation+=1;closing=false;mode=""
	if is_instance_valid(root):root.hide();root.modulate=Color.WHITE
	hide();set_process(false)
	if is_instance_valid(background):background.texture=null
	AssetStream.hold(REF.paths(BAR_KEYS),"loading-ui")
	history.append({"event":"cancelled","reason":reason,"ticket":ticket})
