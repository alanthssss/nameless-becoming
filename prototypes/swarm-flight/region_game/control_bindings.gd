extends RefCounted

signal changed

const ACTIONS := ["up","down","left","right","interact","pulse","dash","pause","mute"]
const SLOTS := ["key","mouse","pad"]
const TITLES := {"up":"向上飞","down":"向下飞","left":"向左飞","right":"向右飞","interact":"互动 / 采集","pulse":"振翅","dash":"蓄力冲刺","pause":"暂停","mute":"静音"}
const DEFAULTS := {
	"key":{"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"pulse":[KEY_Q],"dash":[KEY_SPACE],"pause":[KEY_ESCAPE],"mute":[KEY_M]},
	"mouse":{"interact":[MOUSE_BUTTON_LEFT],"pulse":[MOUSE_BUTTON_RIGHT]},
	"pad":{"up":[JOY_BUTTON_DPAD_UP],"down":[JOY_BUTTON_DPAD_DOWN],"left":[JOY_BUTTON_DPAD_LEFT],"right":[JOY_BUTTON_DPAD_RIGHT],"interact":[JOY_BUTTON_A],"pulse":[JOY_BUTTON_X],"dash":[JOY_BUTTON_RIGHT_SHOULDER],"pause":[JOY_BUTTON_START]},
}
const STICK_HINTS := {"up":"左摇杆↑","down":"左摇杆↓","left":"左摇杆←","right":"左摇杆→"}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT:"鼠标左键",MOUSE_BUTTON_RIGHT:"鼠标右键",MOUSE_BUTTON_MIDDLE:"鼠标中键",MOUSE_BUTTON_XBUTTON1:"鼠标侧键 1",MOUSE_BUTTON_XBUTTON2:"鼠标侧键 2"}
const PAD_NAMES := ["A（下）","B（右）","X（左）","Y（上）","Back","Guide","Start","左摇杆按下","右摇杆按下","LB","RB","十字键↑","十字键↓","十字键←","十字键→","分享","背键 1","背键 2","背键 3","背键 4","触摸板按下"]
const KEY_NAMES := {KEY_SPACE:"空格",KEY_ESCAPE:"Esc",KEY_UP:"↑",KEY_DOWN:"↓",KEY_LEFT:"←",KEY_RIGHT:"→",KEY_ENTER:"Enter"}

var mapping: Dictionary = DEFAULTS.duplicate(true)
var path := "user://nectar_region_controls.cfg"

func load_from(file_path: String) -> void:
	path = file_path
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("controls","version",0) != 1: return
	var candidate := DEFAULTS.duplicate(true)
	for slot in SLOTS:
		var occupied := {}
		for action in ACTIONS:
			var codes: Variant = config.get_value(slot,action,DEFAULTS[slot].get(action,[]))
			if not codes is Array: return
			for code in codes:
				if not code is int or not allowed(slot,code,action) or occupied.has(code): return
				occupied[code] = true
			candidate[slot][action] = codes
	mapping = candidate

static func slot_for(event: InputEvent) -> String:
	if event is InputEventKey: return "key"
	if event is InputEventMouseButton: return "mouse"
	if event is InputEventJoypadButton: return "pad"
	return ""

static func code_for(event: InputEvent) -> int:
	if event is InputEventKey: return event.physical_keycode if event.physical_keycode else event.keycode
	if event is InputEventMouseButton or event is InputEventJoypadButton: return event.button_index
	return -1

static func allowed(slot: String, code: int, action: String) -> bool:
	match slot:
		"key": return code > 0 and code < KEY_UNKNOWN and (code != KEY_ESCAPE or action == "pause")
		"mouse": return MOUSE_NAMES.has(code)
		"pad": return code >= 0 and code < JOY_BUTTON_MAX and code not in [JOY_BUTTON_B,JOY_BUTTON_GUIDE] and (code != JOY_BUTTON_START or action == "pause")
	return false

func action_for(slot: String, code: int) -> String:
	for action in mapping.get(slot,{}):
		if code in mapping[slot][action]: return action
	return ""

func rebind(action: String, slot: String, event: InputEvent) -> String:
	if action not in ACTIONS or slot not in SLOTS: return "未找到这项操作"
	if slot_for(event) != slot or not event.is_pressed() or event.is_echo():
		return {"key":"请按键盘按键","mouse":"请按鼠标按键","pad":"请按手柄按钮"}[slot]
	var code := code_for(event)
	if not allowed(slot,code,action): return "此键已保留或无法绑定，请换一个"
	var owner := action_for(slot,code)
	if owner != "" and owner != action: return "此键已用于「%s」，请换一个" % TITLES[owner]
	if code in mapping[slot].get(action,[]): return ""
	var candidate := mapping.duplicate(true)
	candidate[slot][action] = [code]
	return _save(candidate)

func reset_defaults() -> String:
	return _save(DEFAULTS.duplicate(true))

func _save(candidate: Dictionary) -> String:
	var config := ConfigFile.new()
	config.set_value("controls","version",1)
	for slot in SLOTS:
		for action in ACTIONS:
			config.set_value(slot,action,candidate[slot].get(action,[]))
	var temporary := "%s.%s.%s.tmp" % [path,OS.get_process_id(),get_instance_id()]
	if config.save(temporary) != OK: return "按键设置保存失败，请重试"
	if DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary)
		return "按键设置保存失败，请重试"
	mapping = candidate
	changed.emit()
	return ""

func label(action: String, slot: String) -> String:
	var names := PackedStringArray()
	for code in mapping.get(slot,{}).get(action,[]):
		match slot:
			"key":
				var key: int = code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code)
				names.append(KEY_NAMES.get(code,OS.get_keycode_string(key if key else code)))
			"mouse": names.append(MOUSE_NAMES[code])
			"pad": names.append(PAD_NAMES[code] if code < PAD_NAMES.size() else "按钮 %d" % (code+1))
	return " / ".join(names) if not names.is_empty() else "—"

func hint(action: String, device: String) -> String:
	var names := PackedStringArray()
	var slots := ["pad"] if device == "pad" else ["key","mouse"]
	for slot in slots:
		var name := label(action,slot)
		if name != "—": names.append(name)
	if device == "pad" and action in STICK_HINTS: names.append(STICK_HINTS[action])
	if action == "pause":
		var fallback := "Start" if device == "pad" else "Esc"
		if fallback not in names: names.append(fallback)
	return " / ".join(names) if not names.is_empty() else "未绑定"
