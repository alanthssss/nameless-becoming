class_name PlaytestSliceRegistry
extends RefCounted

# A catalog row is not an implementation. B01 is reserved here so a future
# typed scene can be compiled into the build without accepting a path from a
# ticket or catalog. It deliberately remains null while the production row is
# blocked.
const COMPILED_SLICE_SCENES := {
	"B01": null,
}

func has_code(code: String) -> bool:
	return COMPILED_SLICE_SCENES.has(code)

func scene_for_code(code: String) -> PackedScene:
	var candidate = COMPILED_SLICE_SCENES.get(code)
	return candidate as PackedScene if candidate is PackedScene else null
