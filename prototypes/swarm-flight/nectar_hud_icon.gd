extends Control
const Art = preload("res://nectar_ui_art.gd")
var kind := "bag"
func _draw() -> void:
	Art.icon(self,kind,size*.5,14)
