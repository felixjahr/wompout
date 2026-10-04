extends Node
class_name HttpUtils

const REQUEST_TIMEOUT := 10.0


static func request(parent: Node, url: String, method: int, body: Variant = null, headers: Array[String] = []) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	parent.add_child(http)

	var request_body := ""
	if body != null:
		request_body = JSON.stringify(body)

	var final_headers := ["Content-Type: application/json"]
	final_headers.append_array(headers)

	var err := http.request(url, final_headers, method, request_body)

	if err != OK:
		http.queue_free()
		push_error("Request failed to start")
		return {
			"ok": false,
			"status": 0,
			"result": HTTPRequest.RESULT_CANT_CONNECT,
			"data": null,
			"text": "",
		}

	var result = await http.request_completed
	http.queue_free()

	var request_result: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var text := response_body.get_string_from_utf8()
	var data = null
	if not text.strip_edges().is_empty():
		data = JSON.parse_string(text)
		if data == null:
			push_error("HTTP response was not valid JSON")

	var ok = response_code >= 200 and response_code < 300
	if request_result != HTTPRequest.RESULT_SUCCESS:
		push_error("HTTP transport failed: result=%s status=%s url=%s" % [request_result, response_code, url])
	elif not ok:
		push_error("HTTP error: %s" % response_code)

	return {
		"ok": ok and request_result == HTTPRequest.RESULT_SUCCESS,
		"status": response_code,
		"result": request_result,
		"data": data,
		"text": text,
	}
