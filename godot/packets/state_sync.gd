class_name StateSync
extends RefCounted

var phase: int
var payload: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"payload": payload,
	}


static func from_dict(data: Dictionary) -> StateSync:
	var state_sync := StateSync.new()
	state_sync.phase = data["phase"]
	state_sync.payload = data.get("payload", {})
	return state_sync
