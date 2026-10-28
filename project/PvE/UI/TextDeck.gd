extends RefCounted
## Long rule text uses explicit page buttons instead of tiny type or scrolling.
var ui
var label:Label
var counter:Label
var previous:Button
var next:Button
var pages:Array[String]=[]
var index=0
func _init(shell,parent:Node,text:String,width:float,height:float,font_size:int):
	ui=shell
	var root=VBoxContainer.new();root.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(root)
	label=ui.owner.label("",root,font_size);label.custom_minimum_size=Vector2(width,height)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	label.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;label.set_meta("text_deck",true)
	var font=label.get_theme_font("font");var size=label.get_theme_font_size("font_size")
	var lines:Array[String]=[];var line=""
	for character in text:
		if character=="\n":lines.append(line);line="";continue
		if not line.is_empty() and font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width-12:
			var split=line.rfind(" ")
			if split>line.length()/2:lines.append(line.substr(0,split));line=line.substr(split+1)+character
			else:lines.append(line);line=character
		else:line+=character
	if not line.is_empty() or lines.is_empty():lines.append(line)
	var max_lines=maxi(1,floori((height-6)/font.get_height(size)))
	for first in range(0,lines.size(),max_lines):pages.append("\n".join(lines.slice(first,mini(first+max_lines,lines.size()))))
	label.set_meta("source_text",text);label.set_meta("deck_pages",pages)
	var nav=ui.row(root)
	previous=ui.symbol(nav,"previous",ui.words("上一段","Previous text"),func():show_index(index-1),Vector2(64,56))
	counter=ui.owner.label("",nav,20);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;counter.custom_minimum_size.x=88
	next=ui.symbol(nav,"next",ui.words("下一段","Next text"),func():show_index(index+1),Vector2(64,56))
	nav.visible=pages.size()>1
	show_index(0)
func show_index(value:int):
	index=clampi(value,0,pages.size()-1);label.text=pages[index]
	label.set_meta("text_page",index);label.set_meta("text_pages",pages.size())
	counter.text=str(index+1)+" / "+str(pages.size());previous.disabled=index==0;next.disabled=index==pages.size()-1
