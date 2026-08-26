class_name JourneyState
extends RefCounted

## Session-owned state for the first product journey. Area scenes are disposable:
## changing from the hive threshold to the field must never duplicate a deposit or
## turn a rest stop into a second home.

var reserve := 0
var sortie_count := 0
var active_token := 0
var settled_token := -1
var last_deposit := 0
var completed_pollinations := 0
var first_return_complete := false


func begin_sortie() -> int:
	sortie_count += 1
	active_token += 1
	settled_token = -1
	last_deposit = 0
	completed_pollinations = 0
	return active_token


func next_field_context() -> Dictionary:
	return {
		"journey_token": active_token + 1,
		"reserve": reserve,
		"sortie_count": sortie_count + 1,
	}


func can_settle_return(token: int, deposit: int, pollinations: int) -> bool:
	return token == active_token and token != settled_token and deposit >= 0 and pollinations >= 0


func settle_return(token: int, deposit: int, pollinations: int) -> bool:
	if not can_settle_return(token, deposit, pollinations):
		return false
	settled_token = token
	last_deposit = deposit
	completed_pollinations = pollinations
	reserve += deposit
	first_return_complete = true
	return true


func preview_return_context(deposit: int, pollinations: int) -> Dictionary:
	return {
		"returning": true,
		"deposit_amount": maxi(0, deposit),
		"pollinations": maxi(0, pollinations),
		"reserve": reserve + maxi(0, deposit),
		"first_return_complete": true,
	}


func field_context() -> Dictionary:
	return {
		"journey_token": active_token,
		"reserve": reserve,
		"sortie_count": sortie_count,
	}


func hive_context(returning: bool) -> Dictionary:
	return {
		"returning": returning,
		"deposit_amount": last_deposit if returning else 0,
		"pollinations": completed_pollinations if returning else 0,
		"reserve": reserve,
		"first_return_complete": first_return_complete,
	}
