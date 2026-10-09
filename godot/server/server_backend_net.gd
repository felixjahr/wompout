extends Node

const HTTP_TIMEOUT_SECONDS := 10.0
const REQUEST_ATTEMPTS := 5

var backend_url := ""
var callback_token := ""


func mark_ready(game_id: String) -> bool:
	return await _request("/game-servers/%s/ready" % game_id)


func report_results(game_id: String, results: Array) -> bool:
	return await _request(
		"/game-servers/%s/results" % game_id,
		{"results": results}
	)


func end_game(game_id: String) -> bool:
	return await _request("/game-servers/%s/end" % game_id)


func _request(path: String, body: Variant = null, headers: Array[String] = [], method := HTTPClient.METHOD_POST) -> bool:
	var final_headers := [
		"Authorization: Bearer " + callback_token,
		"Content-Type: application/json",
	]
	final_headers.append_array(headers)
	
	var request_body := JSON.stringify(body) if body != null else ""
	
	for attempt in REQUEST_ATTEMPTS:
		var http := HTTPRequest.new()
		http.timeout = HTTP_TIMEOUT_SECONDS
		add_child(http)
		
		var err := http.request(backend_url + path, final_headers, method, request_body)
		
		if err != OK:
			http.queue_free()
			push_error("Couldn't start request to %s: %s" % [path, err])
		else:
			var response: Array = await http.request_completed
			http.queue_free()
			
			var transport_result: int = response[0]
			var status: int = response[1]
			
			if transport_result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
				return true
			
			push_error("Request failed for %s: transport=%d, HTTP=%d" % [path, transport_result, status])
		
		if attempt < REQUEST_ATTEMPTS - 1:
			await get_tree().create_timer(1.0).timeout
	
	return false
