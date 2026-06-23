class_name BeatSaverPackageFetcher
extends RefCounted

const BeatSaverHttpClient = preload("res://../src/client/beatsaver_http_client.gd")
const BeatSaverMapDetail = preload("res://../src/models/beatsaver_map_detail.gd")
const BeatSaverVersionRef = preload("res://../src/models/beatsaver_version_ref.gd")

var _http_client: BeatSaverHttpClient
var _downloader: Callable

func _init(http_client: BeatSaverHttpClient = null, downloader: Callable = Callable()) -> void:
	_http_client = http_client if http_client != null else BeatSaverHttpClient.new()
	_downloader = downloader

func fetch_version_package(map_detail: BeatSaverMapDetail, version_ref: BeatSaverVersionRef, staging_root: String, options: Dictionary = {}) -> Dictionary:
	if map_detail == null:
		return _error_result("map_detail is required")
	if version_ref == null:
		return _error_result("version_ref is required")
	if version_ref.download_url.strip_edges().is_empty():
		return _error_result("Selected BeatSaver version is missing a download URL.")

	var normalized_root := _normalize_staging_root(staging_root)
	if normalized_root.is_empty():
		return _error_result("staging_root is required")
	var stage_directory_path := _join_paths(normalized_root, "%s/%s" % [_sanitize_segment(map_detail.map_id), _sanitize_segment(version_ref.hash)])
	var ensure_stage_dir_error := DirAccess.make_dir_recursive_absolute(stage_directory_path)
	if ensure_stage_dir_error != OK:
		return _error_result("Failed to create stage directory: %s" % error_string(ensure_stage_dir_error), ensure_stage_dir_error)

	var archive_file_name := str(options.get("archive_file_name", _default_archive_file_name(map_detail, version_ref)))
	var archive_path := _join_paths(stage_directory_path, archive_file_name)
	var download_result := _download_to_file(version_ref.download_url, archive_path, options)
	if not download_result.get("ok", false):
		return download_result

	return {
		"ok": true,
		"stage_root_path": normalized_root,
		"stage_directory_path": stage_directory_path,
		"archive_path": archive_path,
		"archive_file_name": archive_file_name,
		"archive_size_bytes": int(FileAccess.get_file_as_bytes(archive_path).size()),
		"version_hash": version_ref.hash,
		"version_key": version_ref.key,
		"download_url": version_ref.download_url
	}

func _download_to_file(download_url: String, destination_path: String, options: Dictionary) -> Dictionary:
	if _downloader.is_valid():
		return _downloader.call(download_url, destination_path, options)

	var response := _http_client.execute({
		"method": "GET",
		"url": download_url,
		"headers": {"Accept": "application/octet-stream"},
		"expects": "binary"
	}, options)
	if not response.get("ok", false):
		return response
	var body_bytes: PackedByteArray = response.get("payload", PackedByteArray())
	var file := FileAccess.open(destination_path, FileAccess.WRITE)
	if file == null:
		return _error_result("Failed to open destination archive for writing: %s" % destination_path)
	file.store_buffer(body_bytes)
	file.flush()
	file.close()
	return {"ok": true, "destination_path": destination_path, "bytes_written": body_bytes.size()}

func _normalize_staging_root(staging_root: String) -> String:
	var trimmed := staging_root.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return ProjectSettings.globalize_path(trimmed)
	return trimmed

func _default_archive_file_name(map_detail: BeatSaverMapDetail, version_ref: BeatSaverVersionRef) -> String:
	return "%s-%s.zip" % [_sanitize_segment(map_detail.map_id), _sanitize_segment(version_ref.hash.substr(0, min(12, version_ref.hash.length())))]

func _sanitize_segment(value: String) -> String:
	var lowered := value.strip_edges().to_lower()
	var sanitized := ""
	for index in range(lowered.length()):
		var character := lowered[index]
		if character in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", "_"]:
			sanitized += character
		else:
			sanitized += "-"
	while sanitized.contains("--"):
		sanitized = sanitized.replace("--", "-")
	if sanitized.is_empty():
		return "artifact"
	return sanitized.trim_prefix("-").trim_suffix("-")

func _join_paths(left: String, right: String) -> String:
	return "%s/%s" % [left.rstrip("/"), right.trim_prefix("/")]

func _error_result(message: String, code: int = ERR_INVALID_PARAMETER) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"category": "acquisition",
			"message": message,
			"code": code
		}
	}
