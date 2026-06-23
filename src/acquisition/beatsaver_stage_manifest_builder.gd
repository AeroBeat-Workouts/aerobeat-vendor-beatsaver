class_name BeatSaverStageManifestBuilder
extends RefCounted

const BeatSaverMapDetail = preload("res://../src/models/beatsaver_map_detail.gd")
const BeatSaverSourcePackageManifest = preload("res://../src/models/beatsaver_source_package_manifest.gd")
const BeatSaverVersionRef = preload("res://../src/models/beatsaver_version_ref.gd")

func build_manifest(map_detail: BeatSaverMapDetail, version_ref: BeatSaverVersionRef, stage_result: Dictionary, archive_report: Dictionary) -> BeatSaverSourcePackageManifest:
	var info_dat: Dictionary = archive_report.get("parsed_info_dat", {}) if archive_report.get("parsed_info_dat", {}) is Dictionary else {}
	var archive_entries: Array = archive_report.get("entries", []) if archive_report.get("entries", []) is Array else []
	var difficulty_files := _normalize_difficulty_files(info_dat, archive_entries)
	var audio_files := _normalize_audio_files(info_dat, archive_report.get("audio_file_candidates", []))
	var characteristics := _normalize_characteristics(info_dat)
	return BeatSaverSourcePackageManifest.new({
		"map_id": map_detail.map_id,
		"map_key": map_detail.map_key,
		"map_name": map_detail.map_name,
		"version_hash": version_ref.hash,
		"version_key": version_ref.key,
		"version_download_url": version_ref.download_url,
		"stage_root_path": str(stage_result.get("stage_root_path", "")),
		"stage_directory_path": str(stage_result.get("stage_directory_path", "")),
		"archive_path": str(stage_result.get("archive_path", "")),
		"archive_file_name": str(archive_report.get("archive_file_name", stage_result.get("archive_file_name", ""))),
		"archive_size_bytes": int(archive_report.get("archive_size_bytes", stage_result.get("archive_size_bytes", 0))),
		"archive_entry_count": int(archive_report.get("entry_count", archive_entries.size())),
		"archive_entries": archive_entries,
		"info_dat_path": str(archive_report.get("selected_info_dat_path", "")),
		"song_filename": str(info_dat.get("song_filename", "")),
		"cover_image_filename": str(info_dat.get("cover_image_filename", "")),
		"audio_files": audio_files,
		"difficulty_files": difficulty_files,
		"beatmap_characteristics": characteristics,
		"raw_archive_report": archive_report
	})

func save_manifest(manifest: BeatSaverSourcePackageManifest, manifest_path: String) -> Dictionary:
	var parent_dir := manifest_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent_dir)
	if dir_error != OK:
		return _error_result("Failed to create manifest directory: %s" % error_string(dir_error), dir_error)
	manifest.manifest_path = manifest_path
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return _error_result("Failed to open manifest path for writing: %s" % manifest_path)
	file.store_string(JSON.stringify(manifest.to_dictionary(), "	"))
	file.flush()
	file.close()
	return {"ok": true, "manifest_path": manifest_path}

func _normalize_audio_files(info_dat: Dictionary, archive_candidates: Array) -> Array:
	var normalized: Array = []
	var seen_paths := {}
	var song_filename := str(info_dat.get("song_filename", ""))
	if not song_filename.is_empty():
		normalized.append({
			"path": song_filename,
			"referenced_by_info_dat": true,
			"extension": song_filename.get_extension().to_lower()
		})
		seen_paths[song_filename.to_lower()] = true
	for candidate in archive_candidates:
		if not candidate is Dictionary:
			continue
		var path := str(candidate.get("path", ""))
		var normalized_key := path.to_lower()
		if normalized_key.is_empty() or seen_paths.has(normalized_key):
			continue
		var entry: Dictionary = candidate.duplicate(true)
		entry["referenced_by_info_dat"] = path == song_filename
		normalized.append(entry)
		seen_paths[normalized_key] = true
	return normalized

func _normalize_difficulty_files(info_dat: Dictionary, archive_entries: Array) -> Array:
	var normalized: Array = []
	var seen_paths := {}
	for difficulty in info_dat.get("difficulties", []):
		if not difficulty is Dictionary:
			continue
		var path := str(difficulty.get("path", ""))
		if path.is_empty():
			continue
		var entry: Dictionary = difficulty.duplicate(true)
		entry["referenced_by_info_dat"] = true
		normalized.append(entry)
		seen_paths[path.to_lower()] = true
	for archive_entry in archive_entries:
		if not archive_entry is Dictionary:
			continue
		if not archive_entry.get("is_difficulty_candidate", false):
			continue
		var archive_path := str(archive_entry.get("path", ""))
		var archive_key := archive_path.to_lower()
		if archive_key.is_empty() or seen_paths.has(archive_key):
			continue
		normalized.append({
			"path": archive_path,
			"difficulty": "",
			"difficulty_rank": 0,
			"characteristic": "",
			"note_jump_movement_speed": 0.0,
			"note_jump_start_beat_offset": 0.0,
			"referenced_by_info_dat": false
		})
		seen_paths[archive_key] = true
	return normalized

func _normalize_characteristics(info_dat: Dictionary) -> Array:
	var normalized: Array = []
	for characteristic in info_dat.get("characteristics", []):
		if characteristic is Dictionary:
			normalized.append(characteristic.duplicate(true))
	return normalized

func _error_result(message: String, code: int = ERR_INVALID_DATA) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"category": "manifest",
			"message": message,
			"code": code
		}
	}
