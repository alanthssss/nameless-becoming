class_name PlaytestSliceRegistry
extends RefCounted

# A catalog row is not an implementation. Every runnable slice is compiled into
# this registry so neither a ticket nor the public catalog can inject a scene or
# handler path.
const COMPILED_SLICE_SCENES := {
	"B01": preload("res://playtest/b01_evade_slice.tscn"),
}

func has_code(code: String) -> bool:
	return COMPILED_SLICE_SCENES.has(code)

func scene_for_code(code: String) -> PackedScene:
	var candidate = COMPILED_SLICE_SCENES.get(code)
	return candidate as PackedScene if candidate is PackedScene else null
