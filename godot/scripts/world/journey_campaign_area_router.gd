class_name JourneyCampaignAreaRouter
extends Node

signal area_changed(area_id: String, area: Node)

const HIVE_SCENE := preload("res://world/journey/campaign_hive.tscn")
const FIELD_SCENE := preload("res://world/journey/campaign_field.tscn")
const FIELD_KEYS := [
	"spring_prologue", "spring_term_field", "spring_climax",
	"summer_term_field", "summer_climax",
	"autumn_term_field", "autumn_climax",
	"winter_term_field", "winter_climax",
]

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
	return area_id == "hive_threshold" or area_id in FIELD_KEYS


func change_area(area_id: String, context: Dictionary = {}) -> Error:
	if host == null:
		return ERR_UNCONFIGURED
	if changing:
		return ERR_BUSY
	if not has_area(area_id):
		return ERR_DOES_NOT_EXIST
	changing = true
	var packed := HIVE_SCENE if area_id == "hive_threshold" else FIELD_SCENE
	var next_area := packed.instantiate()
	if next_area.has_method("configure"):
		var configured = next_area.configure(context)
		if configured is int and int(configured) != OK:
			next_area.free()
			changing = false
			return int(configured)
	var previous := current_area
	if previous != null:
		if previous.get_parent() == host:
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
