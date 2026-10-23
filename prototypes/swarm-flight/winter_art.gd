extends RefCounted
## One region switch for every shared plant path, including stormy winter level15.
## Winter textures change presentation only; geometry and state stay in the model.
const ATLAS: Texture2D = preload("res://art/winter-plants.png")
const HOME: Texture2D = preload("res://art/winter-home.png")
const STEM_CORE := Rect2(260,160,115,490)
const STEM_CAP := Rect2(246,87,145,53)
const FLOWER := Rect2(643,83,582,607)
const FLOWER_PIVOT := Vector2(928,412)
const LEAF := Rect2(21,843,639,281)
const ARCH := Rect2(706,738,532,485)
const INK := Color("55483e")
const FROST := Color("d8e6ed")

static func active(v: Node2D) -> bool:
	return v.model != null and int(v.model.chapter.get("region",-1)) == 3
