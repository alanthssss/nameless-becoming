extends RefCounted
## Only this boundary accepts v1. The live transaction writer remains v2-only.
const Model = preload("res://nectar_harvest_model.gd")
const Save = preload("res://save_data.gd")

static func load_progress(path: String) -> Dictionary:
	var result := {"ok":false,"existed":FileAccess.file_exists(path),"blocked":false,"migrated":false,"payload":{},"error":""}
	if not result.existed: return result
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > Save.MAX_BYTES:
		return _block(result,"进度文件无法读取或超过允许大小")
	var original := file.get_buffer(file.get_length())
	file.close()
	var parser := JSON.new()
	if parser.parse(original.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _block(result,"进度文件不是有效的采蜜记录")
	var data: Dictionary = parser.data
	var model = Model.new()
	if Model.whole(data.get("version"),2,2):
		if not model.restore_payload(data): return _block(result,"这份采蜜进度未通过完整性检查")
		result.ok = true
		result.payload = model.to_payload()
		return result
	if not Model.whole(data.get("version"),1,1) or not model.restore_v1_payload(data):
		return _block(result,"旧版采蜜进度未通过完整性检查")
	# Write an exact rollback copy before replacing the original. Never replace a
	# different existing backup, including one left by an earlier migration.
	var backup := path+".v1.bak"
	if FileAccess.file_exists(backup):
		if FileAccess.get_file_as_bytes(backup) != original:
			return _block(result,"已有旧版备份与当前进度不同，原进度保持不变")
	else:
		var temporary := backup+".tmp"
		var output := FileAccess.open(temporary,FileAccess.WRITE)
		if output == null: return _block(result,"旧版进度备份无法写入，尚未升级进度")
		output.store_buffer(original)
		output.flush()
		var written := output.get_error() == OK
		output.close()
		if not written or FileAccess.get_file_as_bytes(temporary) != original:
			DirAccess.remove_absolute(temporary)
			return _block(result,"旧版进度备份校验失败，尚未升级进度")
		if DirAccess.rename_absolute(temporary,backup) != OK:
			DirAccess.remove_absolute(temporary)
			return _block(result,"旧版进度备份无法完成，尚未升级进度")
	# A second running application must not have changed v1 while we prepared its
	# backup. A failed write below leaves that original file intact.
	if FileAccess.get_file_as_bytes(path) != original:
		return _block(result,"进度被其他窗口修改，请关闭其他窗口后重试")
	var migrated: Dictionary = model.to_payload()
	if not Save.write_payload(migrated,path,Model.new()):
		return _block(result,"新版进度无法保存，旧版进度和备份均已保留")
	result.ok = true
	result.migrated = true
	result.payload = migrated
	return result

static func _block(result: Dictionary,message: String) -> Dictionary:
	result.blocked = true
	result.error = message
	return result
