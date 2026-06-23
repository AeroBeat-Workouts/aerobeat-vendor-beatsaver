class_name BeatSaverRemoteImage
extends TextureRect

const PLACEHOLDER_SIZE := Vector2i(256, 144)
const PLACEHOLDER_COLOR := Color("2f3440")
const PLACEHOLDER_ACCENT := Color("566079")

var _request: HTTPRequest
var _current_url: String = ""

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture = _build_placeholder_texture()
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = 10.0
		add_child(_request)
		_request.request_completed.connect(_on_request_completed)

func set_image_url(url: String) -> void:
	_current_url = url.strip_edges()
	tooltip_text = _current_url
	texture = _build_placeholder_texture()
	if _current_url.is_empty():
		return
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if _request == null:
		return
	if _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_request.cancel_request()
	var request_error := _request.request(_current_url)
	if request_error != OK:
		push_warning("Failed to request BeatSaver cover image: %s" % error_string(request_error))

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or body.is_empty():
		return
	var image := Image.new()
	var content_type := _extract_header(headers, "content-type")
	var load_error := _load_image_from_buffer(image, body, _current_url, content_type)
	if load_error != OK:
		push_warning("Failed to decode BeatSaver cover image from %s: %s" % [_current_url, error_string(load_error)])
		return
	texture = ImageTexture.create_from_image(image)

func _extract_header(headers: PackedStringArray, name: String) -> String:
	var prefix := "%s:" % name.to_lower()
	for line in headers:
		if line.to_lower().begins_with(prefix):
			return line.substr(line.find(":") + 1).strip_edges()
	return ""

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
		for x in range(PLACEHOLDER_SIZE.x):
			if int((x / 24) + (y / 24)) % 2 == 0:
				image.set_pixel(x, y, PLACEHOLDER_ACCENT)
	return ImageTexture.create_from_image(image)
