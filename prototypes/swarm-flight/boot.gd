extends Node
## Export templates disallow scene paths on the command line. Route explicit
## sample selection inside the game instead; old launch flags remain unchanged.
func _ready() -> void:
	var args:=OS.get_cmdline_user_args()
	var scene := "res://spring_journey.tscn"
	if "--long-journey" in args or "--classic-journey" in args or "--swarm-qa" in args: scene="res://main.tscn"
	if "--weather-window" in args: scene="res://weather_window.tscn"
	if "--bee-dance" in OS.get_cmdline_user_args(): scene = "res://bee_dance.tscn"
	if "--sign-keeper" in OS.get_cmdline_user_args(): scene = "res://sign_keeper.tscn"
	if "--spring-journey" in OS.get_cmdline_user_args(): scene = "res://spring_journey.tscn"
	get_tree().change_scene_to_file.call_deferred(scene)
