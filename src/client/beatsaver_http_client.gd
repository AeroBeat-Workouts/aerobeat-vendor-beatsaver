class_name BeatSaverHttpClient
extends RefCounted

const DEFAULT_TIMEOUT_SECONDS := 30.0

var _executor: Callable

func _init(executor: Callable = Callable()) -> void:
	_executor = executor

func execute(request: Dictionary, options: Dictionary = {}) -> Dictionary:
	var final_request := prepare_request(request)
	var raw_result := _dispatch_request(final_request, options)
	if raw_result.get("transport_error", "") != "":
		return {
			"ok": false,
			"status_code": -1,
			"headers": {},
			"payload": null,
			"request": final_request,
			"error": {
				"category": "transport",
				"message": str(raw_result.transport_error),
				"code": int(raw_result.get("code", ERR_CANT_CONNECT))
			}
		}

	var body_bytes: PackedByteArray = raw_result.get("body_bytes", PackedByteArray())
	var payload = raw_result.get("payload", null)
	var body := str(raw_result.get("body", body_bytes.get_string_from_utf8()))
	if payload == null:
		payload = _decode_payload(body_bytes, body, str(final_request.get("expects", "json")))
	var normalized := normalize_response(int(raw_result.get("status_code", 0)), raw_result.get("headers", {}), payload)
	normalized["request"] = final_request
	normalized["raw_body"] = body if str(final_request.get("expects", "json")) != "binary" else ""
	normalized["raw_body_bytes"] = body_bytes
	return normalized

func prepare_request(request: Dictionary) -> Dictionary:
	var explicit_url := str(request.get("url", "")).strip_edges()
	if not explicit_url.is_empty():
		var parsed := _parse_url(explicit_url)
		assert(parsed.get("ok", false))
		var request_path := str(parsed.get("request_path", "/"))
		var query_index := request_path.find("?")
		var path_only := request_path.substr(0, query_index) if query_index >= 0 else request_path
		return {
			"method": str(request.get("method", "GET")).to_upper(),
			"path": path_only,
			"url": explicit_url,
			"query": _normalize_query(request.get("query", {})),
			"headers": _normalize_headers(request.get("headers", {})),
			"expects": str(request.get("expects", "json")),
			"base_url": "%s://%s%s" % ["https" if parsed.get("tls", false) else "http", str(parsed.get("host", "")), _port_suffix(parsed)]
		}
	var base_url := str(request.get("base_url", "https://api.beatsaver.com")).rstrip("/")
	var path := _normalize_path(str(request.get("path", "/")))
	var query := _normalize_query(request.get("query", {}))
	var query_string := _encode_parameters(query)
	var url := "%s%s" % [base_url, path]
	if not query_string.is_empty():
		url += "?%s" % query_string
	return {
		"method": str(request.get("method", "GET")).to_upper(),
		"path": path,
		"url": url,
		"query": query,
		"headers": _normalize_headers(request.get("headers", {})),
		"expects": str(request.get("expects", "json")),
		"base_url": base_url
	}

func normalize_response(status_code: int, headers: Dictionary = {}, payload: Variant = null) -> Dictionary:
	var normalized_headers := {}
	for key in headers.keys():
		normalized_headers[str(key).to_lower()] = headers[key]
	var ok := status_code >= 200 and status_code < 300
	var response := {
		"ok": ok,
		"status_code": status_code,
		"headers": normalized_headers,
		"payload": payload
	}
	if ok:
		return response
	response["error"] = {
		"category": _categorize_error(status_code),
		"message": _extract_error_message(payload, status_code),
		"details": payload if payload is Dictionary else {},
		"code": status_code
	}
	return response

func _dispatch_request(final_request: Dictionary, options: Dictionary) -> Dictionary:
	if _executor.is_valid():
		return _executor.call(final_request, options)
	return _execute_with_http_client(final_request, options)

func _execute_with_http_client(final_request: Dictionary, options: Dictionary) -> Dictionary:
	var parsed := _parse_url(final_request.url)
	if not parsed.get("ok", false):
		return parsed
	var client := HTTPClient.new()
	var tls_options := TLSOptions.client() if parsed.get("tls", false) else null
	var connect_error := client.connect_to_host(str(parsed.host), int(parsed.port), tls_options)
	if connect_error != OK:
		return {"transport_error": error_string(connect_error), "code": connect_error}
	var timeout_seconds := float(options.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS))
	if not _wait_for_status(client, timeout_seconds, [HTTPClient.STATUS_CONNECTED]):
		return {"transport_error": "Timed out connecting to BeatSaver.", "code": ERR_TIMEOUT}
	var request_error := client.request(_http_method_to_constant(str(final_request.method)), str(parsed.request_path), _headers_to_lines(final_request.headers), "")
	if request_error != OK:
		return {"transport_error": error_string(request_error), "code": request_error}
	if not _wait_for_status(client, timeout_seconds, [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]):
		return {"transport_error": "Timed out waiting for BeatSaver response.", "code": ERR_TIMEOUT}
	var progress_callback: Callable = options.get("progress_callback", Callable())
	var body_chunks := PackedByteArray()
	var content_length := -1
	if client.has_method("get_response_body_length"):
		content_length = int(client.get_response_body_length())
	if progress_callback.is_valid():
		progress_callback.call({
			"bytesDownloaded": 0,
			"contentLength": content_length,
			"progress": 0.0,
		})
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
			continue
		body_chunks.append_array(chunk)
		if progress_callback.is_valid():
			var progress := -1.0
			if content_length > 0:
				progress = minf(float(body_chunks.size()) / float(content_length), 1.0)
			progress_callback.call({
				"bytesDownloaded": body_chunks.size(),
				"contentLength": content_length,
				"progress": progress,
			})
	return {
		"status_code": client.get_response_code(),
		"headers": _response_headers_to_dictionary(client.get_response_headers()),
		"body": body_chunks.get_string_from_utf8(),
		"body_bytes": body_chunks
	}

func _wait_for_status(client: HTTPClient, timeout_seconds: float, terminal_statuses: Array) -> bool:
	var started_at := Time.get_ticks_msec()
	while true:
		client.poll()
		var status := client.get_status()
		if terminal_statuses.has(status):
			return true
		if status == HTTPClient.STATUS_DISCONNECTED:
			return false
		if float(Time.get_ticks_msec() - started_at) / 1000.0 >= timeout_seconds:
			return false
		OS.delay_msec(10)
	return false

func _normalize_query(query: Dictionary) -> Dictionary:
	var normalized := {}
	for key in query.keys():
		normalized[str(key)] = query[key]
	return normalized

func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers.keys():
		normalized[str(key)] = str(headers[key])
	return normalized

func _encode_parameters(values: Dictionary) -> String:
	var keys: Array = values.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for key in keys:
		var value = values[key]
		parts.append("%s=%s" % [str(key).uri_encode(), _parameter_to_string(value).uri_encode()])
	return "&".join(parts)

func _parameter_to_string(value: Variant) -> String:
	if value is bool:
		return "true" if value else "false"
	return str(value)

func _decode_payload(body_bytes: PackedByteArray, raw_body: String, expects: String) -> Variant:
	if expects == "binary":
		return body_bytes
	if expects != "json":
		return raw_body
	var stripped := raw_body.strip_edges()
	if stripped.is_empty():
		return {}
	var parsed = JSON.parse_string(stripped)
	return parsed if parsed != null else raw_body

func _normalize_path(path: String) -> String:
	var sanitized := path.strip_edges()
	if sanitized.is_empty():
		return "/"
	return "/%s" % sanitized.trim_prefix("/")

func _extract_error_message(payload: Variant, status_code: int) -> String:
	if payload is Dictionary:
		if payload.has("message"):
			return str(payload.message)
		if payload.has("error") and payload.error is Dictionary and payload.error.has("message"):
			return str(payload.error.message)
	return "HTTP %d" % status_code

func _categorize_error(status_code: int) -> String:
	if status_code == 404:
		return "not_found"
	if status_code == 429:
		return "rate_limited"
	if status_code >= 500:
		return "server"
	if status_code >= 400:
		return "request"
	return "unknown"

func _parse_url(url: String) -> Dictionary:
	var parts := url.strip_edges().split("://", false, 1)
	if parts.size() != 2:
		return {"ok": false, "transport_error": "Unsupported URL: %s" % url, "code": ERR_INVALID_PARAMETER}
	var scheme := parts[0].to_lower()
	var remainder := parts[1]
	var slash_index := remainder.find("/")
	var host_port := remainder
	var request_path := "/"
	if slash_index >= 0:
		host_port = remainder.substr(0, slash_index)
		request_path = remainder.substr(slash_index)
	var host := host_port
	var port := 443 if scheme == "https" else 80
	if host_port.contains(":"):
		var host_parts := host_port.rsplit(":", true, 1)
		host = host_parts[0]
		port = int(host_parts[1])
	return {"ok": true, "tls": scheme == "https", "host": host, "port": port, "request_path": request_path}

func _headers_to_lines(headers: Dictionary) -> PackedStringArray:
	var keys: Array = headers.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key in keys:
		lines.append("%s: %s" % [str(key), str(headers[key])])
	return lines

func _response_headers_to_dictionary(header_lines: PackedStringArray) -> Dictionary:
	var headers := {}
	for line in header_lines:
		var separator_index := line.find(":")
		if separator_index < 0:
			continue
		headers[line.substr(0, separator_index).strip_edges()] = line.substr(separator_index + 1).strip_edges()
	return headers

func _http_method_to_constant(method: String) -> HTTPClient.Method:
	match method:
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET

func _port_suffix(parsed: Dictionary) -> String:
	var port := int(parsed.get("port", 0))
	var tls := bool(parsed.get("tls", false))
	if (tls and port == 443) or (not tls and port == 80):
		return ""
	return ":%d" % port
