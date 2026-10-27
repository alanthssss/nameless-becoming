extends Node
## Export templates disallow scene paths on the command line. Route explicit
## sample selection inside the game instead; old launch flags remain unchanged.
func _ready() -> void:
	var scene := "res://weather_window.tscn" if "--weather-window" in OS.get_cmdline_user_args() else "res://main.tscn"
	if "--bee-dance" in OS.get_cmdline_user_args(): scene = "res://bee_dance.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)
