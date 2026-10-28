extends RefCounted
## Buttons move between complete layout groups; wheel/drag never drives a menu.
var owner
var ui:
	get:return owner.menus.shell
var footer:HBoxContainer
var previous:Button
var next:Button
var counter:Label
var starts:Array[float]=[0.0]
var index=0
var signature=""
func _init(host,_shell):owner=host
func attach(parent:Node):
	footer=HBoxContainer.new();footer.alignment=BoxContainer.ALIGNMENT_CENTER;footer.add_theme_constant_override("separation",24);parent.add_child(footer)
	previous=ui.symbol(footer,"previous",ui.words("上一页","Previous"),func():turn(-1),Vector2(76,68));previous.name="PagePrevious"
	counter=owner.label("1 / 1",footer,22);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;counter.custom_minimum_size.x=120
	next=ui.symbol(footer,"next",ui.words("下一页","Next"),func():turn(1),Vector2(76,68));next.name="PageNext"
func reset():index=0;signature="";starts=[0.0]
func refresh():
	if not is_instance_valid(footer) or not owner.panel.visible:return
	var body=owner.popup_content;var height=owner.popup_scroll.size.y
	if height<1:return
	var key=str(body.size)+str(height)+str(body.get_child_count())
	for child in body.get_children():
		if child is Control and child.visible:key+=str(child.position)+str(child.size)
	if key==signature:return
	signature=key;starts=[0.0]
	var begin=0.0
	for child in body.get_children():
		if not child is Control or not child.visible:continue
		var top=child.position.y;var bottom=top+child.size.y
		if bottom-begin>height+1 and top>begin+1:starts.append(top);begin=top
		# Explicit decks handle long descriptions; this fallback retains access
		# if a future content block grows beyond one viewport.
		while bottom-begin>height+1:
			begin+=height;starts.append(begin)
	index=clampi(index,0,starts.size()-1)
	_apply()
func turn(direction:int):
	refresh();index=clampi(index+direction,0,starts.size()-1);_apply()
func _apply():
	owner.popup_scroll.scroll_vertical=roundi(starts[index])
	previous.disabled=index==0;next.disabled=index==starts.size()-1
	counter.text=str(index+1)+" / "+str(starts.size())
	footer.modulate.a=1.0 if starts.size()>1 else 0.0
	footer.set_meta("page_count",starts.size());footer.set_meta("page_index",index)
func reveal(control:Control):
	refresh()
	var y=control.get_global_rect().position.y-owner.popup_content.global_position.y
	for n in starts.size():
		if starts[n]<=y:index=n
	_apply()
