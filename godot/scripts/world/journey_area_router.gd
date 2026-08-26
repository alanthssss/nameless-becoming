class_name JourneyAreaRouter
extends Node

signal area_changed(area_id: String, area: Node)

const AREA_SCENES := {
	"hive_threshold": preload("res://world/journey/hive_threshold.tscn"),
	"spring_field": preload("res://world/journey/spring_field.tscn"),
}

var host: Node
var current_area: Node
var current_area_id := ""
var changing := false
var load_count := 0


func configure(area_host: Node) -> Error:
	if host != null or area_host == null:
		return ERR_ALREADY_IN_USE if host != null else ERR_INVALID_PARAMETER
	host = area_host
	return OK


func has_area(area_id: String) -> bool:
	return AREA_SCENES.has(area_id)


func change_area(area_id: String, context: Dictionary = {}) -> Error:
	if host == null:
		return ERR_UNCONFIGURED
	if changing:
		return ERR_BUSY
	if not AREA_SCENES.has(area_id):
		return ERR_DOES_NOT_EXIST
	changing = true
	var next_area := (AREA_SCENES[area_id] as PackedScene).instantiate()
	if next_area.has_method("configure"):
		var configure_error = next_area.configure(context)
		if configure_error is int and int(configure_error) != OK:
			next_area.free()
			changing = false
			return int(configure_error)
	var previous := current_area
	if previous != null:
		host.remove_child(previous)
		previous.queue_free()
	host.add_child(next_area)
	current_area = next_area
	current_area_id = area_id
	load_count += 1
	changing = false
	area_changed.emit(area_id, next_area)
	return OK


func clear() -> void:
	if current_area != null:
		if current_area.get_parent() == host:
			host.remove_child(current_area)
		current_area.queue_free()
	current_area = null
	current_area_id = ""
