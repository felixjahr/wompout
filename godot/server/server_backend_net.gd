extends Node

<<<<<<< HEAD
const REQUEST_ATTEMPTS := 5

var backend_url := ""
var callback_token := ""


func mark_ready(game_id: String) -> bool:
	return await _post("/game-servers/%s/ready" % game_id)


func end_game(game_id: String, results: Array) -> bool:
	return await _post(
		"/game-servers/%s/end" % game_id,
		{"results": results}
	)


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
	
=======
const HTTP_BASE := "http://backend:8000"
const REQUEST_ATTEMPTS := 5

var server_callback_secret: String


func start_room(code: String) -> bool:
	for attempt in REQUEST_ATTEMPTS:
		var response: Dictionary = await HttpUtils.request(
			self,
			HTTP_BASE + "/rooms/start/" + code,
			HTTPClient.METHOD_POST,
			null,
			["x-server-secret: " + server_callback_secret]
		)
		if response.get("ok", false):
			return true
		if attempt < REQUEST_ATTEMPTS - 1:
			await get_tree().create_timer(1.0).timeout
	return false


func end_room(code: String) -> bool:
	for attempt in REQUEST_ATTEMPTS:
		var response: Dictionary = await HttpUtils.request(
			self,
			HTTP_BASE + "/rooms/end/" + code,
			HTTPClient.METHOD_POST,
			null,
			["x-server-secret: " + server_callback_secret]
		)
		if response.get("ok", false):
			return true
		if attempt < REQUEST_ATTEMPTS - 1:
			await get_tree().create_timer(1.0).timeout
>>>>>>> origin/main
	return false
