class_name BeatSaverSourcePackageManifest
extends RefCounted

var provider: String = "beatsaver"
var map_id: String
var map_key: String
var map_name: String
var version_hash: String
var version_key: String
var version_download_url: String
var preview_url: String
var stage_root_path: String
var stage_directory_path: String
var archive_path: String
var archive_file_name: String
var archive_size_bytes: int
var archive_entry_count: int
var archive_entries: Array
var info_dat_path: String
var song_filename: String
var cover_image_filename: String
var audio_files: Array
var difficulty_files: Array
var beatmap_characteristics: Array
var manifest_path: String
var raw_archive_report: Dictionary

func _init(payload: Dictionary = {}) -> void:
	map_id = str(payload.get("map_id", ""))
	map_key = str(payload.get("map_key", map_id))
	map_name = str(payload.get("map_name", ""))
	version_hash = str(payload.get("version_hash", ""))
	version_key = str(payload.get("version_key", ""))
	version_download_url = str(payload.get("version_download_url", ""))
	preview_url = str(payload.get("preview_url", payload.get("previewUrl", payload.get("previewURL", ""))))
	stage_root_path = str(payload.get("stage_root_path", ""))
	stage_directory_path = str(payload.get("stage_directory_path", ""))
	archive_path = str(payload.get("archive_path", ""))
	archive_file_name = str(payload.get("archive_file_name", ""))
	archive_size_bytes = int(payload.get("archive_size_bytes", 0))
	archive_entry_count = int(payload.get("archive_entry_count", 0))
	archive_entries = _duplicate_dictionary_array(payload.get("archive_entries", []))
	info_dat_path = str(payload.get("info_dat_path", ""))
	song_filename = str(payload.get("song_filename", ""))
	cover_image_filename = str(payload.get("cover_image_filename", ""))
	audio_files = _duplicate_dictionary_array(payload.get("audio_files", []))
	difficulty_files = _duplicate_dictionary_array(payload.get("difficulty_files", []))
	beatmap_characteristics = _duplicate_dictionary_array(payload.get("beatmap_characteristics", []))
	manifest_path = str(payload.get("manifest_path", ""))
	raw_archive_report = payload.get("raw_archive_report", {}).duplicate(true) if payload.get("raw_archive_report", {}) is Dictionary else {}

func to_dictionary() -> Dictionary:
	return {
		"provider": provider,
		"map_id": map_id,
		"map_key": map_key,
		"map_name": map_name,
		"version_hash": version_hash,
		"version_key": version_key,
		"version_download_url": version_download_url,
		"preview_url": preview_url,
		"stage_root_path": stage_root_path,
		"stage_directory_path": stage_directory_path,
		"archive_path": archive_path,
		"archive_file_name": archive_file_name,
		"archive_size_bytes": archive_size_bytes,
		"archive_entry_count": archive_entry_count,
		"archive_entries": _duplicate_dictionary_array(archive_entries),
		"info_dat_path": info_dat_path,
		"song_filename": song_filename,
		"cover_image_filename": cover_image_filename,
		"audio_files": _duplicate_dictionary_array(audio_files),
		"difficulty_files": _duplicate_dictionary_array(difficulty_files),
		"beatmap_characteristics": _duplicate_dictionary_array(beatmap_characteristics),
		"manifest_path": manifest_path,
		"raw_archive_report": raw_archive_report.duplicate(true)
	}

func _duplicate_dictionary_array(values: Array) -> Array:
	var normalized: Array = []
	for value in values:
		if value is Dictionary:
			normalized.append(value.duplicate(true))
		else:
			normalized.append(value)
	return normalized
