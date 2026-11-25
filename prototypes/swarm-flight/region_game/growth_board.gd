extends "res://nectar_growth_board.gd"
## Six ways of using the garden. The hexagon is a map; only lines into the
## selected cell describe purchases. The regional model owns all prices.
const POSITIONS := {
	"gather": Vector2(.44,.24), "twin":Vector2(.56,.095),
	"beat":Vector2(.67,.37), "reach":Vector2(.81,.24),
	"bag":Vector2(.75,.62), "wings":Vector2(.50,.77),
	"supply":Vector2(.25,.62), "meadow":Vector2(.30,.39),
	"market":Vector2(.19,.24), "reserve":Vector2(.50,.53)
}
const SECTORS := ["采蜜","取材","载量","续航","花源","经营"]
const INK := Color("6f6844")
const MOSS := Color("61793d")
const WAX := Color("b78136")

func _ready() -> void:
	super._ready()
	for b in buttons.values():
		b.hive_cell = true
		b.size = Vector2(96,86)
	_layout()

func is_revealed(id: String) -> bool:
	return id in POSITIONS and model != null and not model.upgrade(str(definition(id).ranks[0])).is_empty()

func point(id: String) -> Vector2:
	return size*Vector2(POSITIONS.get(id,Vector2(.5,.5)))

func _layout() -> void:
	for id in buttons:
		buttons[id].position = point(id)-Vector2(48,30)
	queue_redraw()

func navigate(key: int, backwards := false) -> void:
	if key == KEY_TAB:
		super.navigate(key,backwards)
		return
	var axes := {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}
	if not key in axes: return
	var origin := point(selected)
	var best := INF
	var destination := selected
	for id in visible_ids():
		var delta := point(id)-origin
		var forward := delta.dot(axes[key])
		if forward < 1.0: continue
		# Favor cells in the requested direction before distant diagonal cells.
		var sideways := absf(delta.cross(axes[key]))
		var score := delta.length() + 2.0*sideways*sideways/forward
		if score < best:
			destination = id
			best = score
	select_node(destination)

func _draw() -> void:
	if model == null or buttons.is_empty(): return
	var center := size*Vector2(.5,.49)
	var radius := minf(size.y*.445,size.x*.53)
	var outside := PackedVector2Array()
	for i in 6:
		outside.append(center+Vector2.from_angle(i*TAU/6.0-PI/2)*radius)
	draw_colored_polygon(outside,Color("eadba123"))
	outside.append(outside[0])
	draw_polyline(outside,Color("aa9066"),1.6,true)
	for i in 6:
		draw_circle(outside[i],3.1,WAX,true,-1,true)
		var mid := (outside[i]+outside[i+1])*.5
		draw_line(center,mid,Color("ad9a723b"),1.0,true)
		var label_at := center+(outside[i]-center)*1.06
		if i in [1,2]: label_at += Vector2(23,0)
		if i in [4,5]: label_at += Vector2(-23,0)
		draw_string(font,label_at+Vector2(-30,5),SECTORS[i],HORIZONTAL_ALIGNMENT_CENTER,60,17,INK)
	_draw_prerequisites()

func _draw_prerequisites() -> void:
	var next := next_id(selected)
	if next.is_empty(): next = str(definition(selected).ranks.back())
	var all_ranks: Array = model.upgrade(next).get("requires",[]).duplicate()
	var options: Array = []
	match next:
		"wings1": options = ["gather1","bag1"]
		"meadow": options = model.MEADOW_GROWTH_RANKS
		"reserve": all_ranks.append("twin")
	for data in NODES:
		if data.id == selected or not is_revealed(data.id): continue
		var lit := false
		var required := false
		var alternative := false
		for id in data.ranks:
			if id in all_ranks: required = true
			if id in options: alternative = true
			if (id in all_ranks or id in options) and id in model.owned: lit = true
		if required or alternative:
			_draw_link(data.id,lit,alternative and not required)

func _draw_link(source: String, owned: bool, optional: bool) -> void:
	var direction := (point(selected)-point(source)).normalized()
	var start := point(source)+direction*35
	var end := point(selected)-direction*35
	var color := MOSS if owned else WAX
	if optional:
		draw_dashed_line(start,end,color,1.7,6,true,true)
	else:
		draw_line(start,end,color,2,true)
	var side := direction.orthogonal()*3.5
	draw_polyline(PackedVector2Array([end-direction*7+side,end,end-direction*7-side]),color,2,true)
