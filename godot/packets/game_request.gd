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
	var game_request := GameRequest.new()
	game_request.type = data["type"]
	game_request.payload = data["payload"]
	return game_request
