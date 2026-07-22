class_name BeatSaverRemoteImage
extends TextureRect

const PLACEHOLDER_SIZE := Vector2i(256, 144)
const PLACEHOLDER_COLOR := Color("2f3440")
const PLACEHOLDER_ACCENT := Color("566079")

var _request: HTTPRequest
var _current_url: String = ""
var _in_flight_url: String = ""
var _loaded_url: String = ""
var _failed_request_urls := {}
var _failed_decode_urls := {}

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture = _build_placeholder_texture()
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = 10.0
		add_child(_request)
		_request.request_completed.connect(_on_request_completed)

func set_image_url(url: String) -> void:
	var normalized_url := url.strip_edges()
	if normalized_url == _current_url and (_loaded_url == normalized_url or _in_flight_url == normalized_url or _failed_request_urls.has(normalized_url) or _failed_decode_urls.has(normalized_url)):
		return
	_current_url = normalized_url
	tooltip_text = _current_url
	texture = _build_placeholder_texture()
	if _current_url.is_empty():
		_loaded_url = ""
		_in_flight_url = ""
		return
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if _request == null:
		return
	if _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_request.cancel_request()
	_in_flight_url = _current_url
	var request_error := _request.request(_current_url)
	if request_error != OK:
		_in_flight_url = ""
		_warn_request_failure_once(_current_url, request_error)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_url := _in_flight_url if not _in_flight_url.is_empty() else _current_url
	_in_flight_url = ""
	if request_url.is_empty() or request_url != _current_url:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or body.is_empty():
		_warn_request_failure_once(request_url, result if result != HTTPRequest.RESULT_SUCCESS else response_code)
		return
	var image := Image.new()
	var content_type := _extract_header(headers, "content-type")
	var load_error := _load_image_from_buffer(image, body, request_url, content_type)
	if load_error != OK:
		_warn_decode_failure_once(request_url, load_error)
		return
	_loaded_url = request_url
	_failed_request_urls.erase(request_url)
	_failed_decode_urls.erase(request_url)
	texture = ImageTexture.create_from_image(image)

func _extract_header(headers: PackedStringArray, header_name: String) -> String:
	var prefix := "%s:" % header_name.to_lower()
	for line in headers:
		if line.to_lower().begins_with(prefix):
			return line.substr(line.find(":") + 1).strip_edges()
	return ""

func _warn_request_failure_once(url: String, error_code: int) -> void:
	if _failed_request_urls.has(url):
		return
	_failed_request_urls[url] = true
	push_warning("Failed to request BeatSaver cover image from %s: %s" % [url, error_string(error_code)])

func _warn_decode_failure_once(url: String, error_code: int) -> void:
	if _failed_decode_urls.has(url):
		return
	_failed_decode_urls[url] = true
	push_warning("Failed to decode BeatSaver cover image from %s: %s" % [url, error_string(error_code)])

func _load_image_from_buffer(image: Image, body: PackedByteArray, url: String, content_type: String) -> int:
	var lower_type := content_type.to_lower()
	var lower_url := url.to_lower()
	if lower_type.contains("png") or lower_url.ends_with(".png"):
		return image.load_png_from_buffer(body)
	if lower_type.contains("jpeg") or lower_type.contains("jpg") or lower_url.ends_with(".jpg") or lower_url.ends_with(".jpeg"):
		return image.load_jpg_from_buffer(body)
	if lower_type.contains("webp") or lower_url.ends_with(".webp"):
		return image.load_webp_from_buffer(body)
	var png_error := image.load_png_from_buffer(body)
	if png_error == OK:
		return OK
	var jpg_error := image.load_jpg_from_buffer(body)
	if jpg_error == OK:
		return OK
	return image.load_webp_from_buffer(body)

func _build_placeholder_texture() -> Texture2D:
	var image := Image.create(PLACEHOLDER_SIZE.x, PLACEHOLDER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(PLACEHOLDER_COLOR)
	for y in range(PLACEHOLDER_SIZE.y):
		var tile_y := floori(float(y) / 24.0)
		for x in range(PLACEHOLDER_SIZE.x):
			var tile_x := floori(float(x) / 24.0)
			if (tile_x + tile_y) % 2 == 0:
				image.set_pixel(x, y, PLACEHOLDER_ACCENT)
	return ImageTexture.create_from_image(image)
