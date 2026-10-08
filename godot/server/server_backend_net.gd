extends Node

const REQUEST_ATTEMPTS := 5

var backend_url := ""
var callback_token := ""


func mark_ready(game_id: String) -> bool:
	return await _post("/game-servers/%s/ready" % game_id)


func report_results(game_id: String, results: Array) -> bool:
	return await _post(
		"/game-servers/%s/results" % game_id,
		{"results": results}
	)


func end_game(game_id: String) -> bool:
	return await _post("/game-servers/%s/end" % game_id)


func _post(path: String, body: Variant = null) -> bool:
	for attempt in REQUEST_ATTEMPTS:
		var response: Dictionary = (
			await HttpUtils.request(
				self,
				backend_url + path,
				HTTPClient.METHOD_POST,
				body,
				[
					"Authorization: Bearer "
					+ callback_token,
				]
			)
		)
	
		if response.get("ok", false):
			return true
	
		if attempt < REQUEST_ATTEMPTS - 1:
			await get_tree().create_timer(1.0).timeout
	
	return false
