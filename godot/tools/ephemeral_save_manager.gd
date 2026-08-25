class_name EphemeralSaveManager
extends NamelessSaveManager

## Internal audition runs must not inherit or overwrite the player's real save.
## Counters are exposed so the regression test can prove that the replacement
## manager, rather than the disk-backed manager, handled initialization.
var load_calls := 0
var save_calls := 0


func load_data() -> void:
	load_calls += 1


func save_data() -> Error:
	save_calls += 1
	return OK
