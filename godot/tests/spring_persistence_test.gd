extends SceneTree
const Scene := preload("res://playtest/spring/spring_route.tscn")
const Driver := preload("res://tools/spring_driver.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "user://spring_test_%d.json" % OS.get_process_id()
	assert(not FileAccess.file_exists(path))
	var scene = Scene.instantiate()
	scene.spring_save_path = path
	root.add_child(scene)
	scene.set_physics_process(false)
	Driver.work(scene.model)
	Driver.home(scene.model)
	scene._save_dawn()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(saved.term == 0 and saved.chapter.day == 2)
	var copy = Scene.instantiate()
	copy.spring_save_path = path
	root.add_child(copy)
	copy.set_physics_process(false)
	assert(copy.term_index == 0 and copy.model.day == 2)
	copy.model.position += Vector2(200, 0)
	copy._restart()
	assert(copy.model.day == 2 and copy.model.position == copy.model.HIVE)
	var bad: Dictionary = saved.duplicate(true)
	bad.term = 2
	assert(not copy.restore_spring(bad), "Future chapters cannot be unlocked by changing a number")
	bad = saved.duplicate(true)
	bad.world = {"broken": {"kind": "repair"}}
	assert(not copy.restore_spring(bad), "Corrupt persistent geometry must be rejected")
	var before := FileAccess.get_file_as_string(path)
	copy.paused = true
	copy._next_term()
	assert(FileAccess.get_file_as_string(path) == before)
	DirAccess.remove_absolute(path)
	for s in [scene, copy]:
		s.landscape.route = null
		s.queue_free()
	await process_frame
	print("SPRING PERSISTENCE TEST PASSED: isolated file, dawn resume, restart, strict chapter prefix, corrupt world rejection")
	quit()
