class_name GameRequest
extends RefCounted

enum Type {
	DRAFT_PROGRESS,
	DRAFT_RESULT,
}

var type: Type
var payload


func to_dict() -> Dictionary:
	return {
		"type": type,
		"payload": payload,
	}


static func from_dict(data: Dictionary) -> GameRequest:
	if not data.get("type") is int:
		return null
	if data["type"] not in [Type.DRAFT_PROGRESS, Type.DRAFT_RESULT]:
		return null
	if not data.get("payload") is Array:
		return null
	var picks: Array = data["payload"]
	if picks.size() > 2:
		return null
	for pick in picks:
		if not pick is int:
			return null
	var game_request := GameRequest.new()
	game_request.type = data["type"]
	game_request.payload = picks
	return game_request
