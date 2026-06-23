class_name BeatSaverArchiveInspector
extends RefCounted

const INFO_DAT_BASENAME := "info.dat"
const AUDIO_EXTENSIONS := ["ogg", "egg", "wav", "mp3"]
const IMAGE_EXTENSIONS := ["jpg", "jpeg", "png", "webp"]
const DIFFICULTY_EXTENSIONS := ["dat", "json"]

func inspect_archive(archive_path: String) -> Dictionary:
	if archive_path.strip_edges().is_empty():
		return _error_result("archive_path is required")
	if not FileAccess.file_exists(archive_path):
		return _error_result("Archive does not exist: %s" % archive_path)

	var reader := ZIPReader.new()
	var open_error := reader.open(archive_path)
	if open_error != OK:
		return _error_result("Failed to open archive: %s" % error_string(open_error), open_error)

	var entry_paths := PackedStringArray(reader.get_files())
	entry_paths.sort()
	var entries: Array = []
	var info_dat_candidates: Array = []
	var audio_file_candidates: Array = []
	var cover_image_candidates: Array = []

	for entry_path in entry_paths:
		var normalized_path := str(entry_path)
		var is_directory := normalized_path.ends_with("/")
		var extension := normalized_path.get_extension().to_lower()
		var entry_size_bytes := 0
		if not is_directory:
			var entry_bytes: PackedByteArray = reader.read_file(normalized_path)
			entry_size_bytes = entry_bytes.size()
		var is_info_dat := normalized_path.get_file().to_lower() == INFO_DAT_BASENAME
		var is_audio := not is_directory and AUDIO_EXTENSIONS.has(extension)
		var is_cover := not is_directory and IMAGE_EXTENSIONS.has(extension)
		var is_difficulty := not is_directory and DIFFICULTY_EXTENSIONS.has(extension) and not is_info_dat
		entries.append({
			"path": normalized_path,
			"basename": normalized_path.get_file(),
			"extension": extension,
			"is_directory": is_directory,
			"size_bytes": entry_size_bytes,
			"is_info_dat": is_info_dat,
			"is_audio_candidate": is_audio,
			"is_cover_image_candidate": is_cover,
			"is_difficulty_candidate": is_difficulty
		})
		if is_info_dat:
			info_dat_candidates.append(normalized_path)
		if is_audio:
			audio_file_candidates.append({"path": normalized_path, "size_bytes": entry_size_bytes, "extension": extension})
		if is_cover:
			cover_image_candidates.append({"path": normalized_path, "size_bytes": entry_size_bytes, "extension": extension})

	var selected_info_dat_path := str(info_dat_candidates[0]) if info_dat_candidates.size() > 0 else ""
	var parsed_info_dat := {}
	if not selected_info_dat_path.is_empty():
		parsed_info_dat = _parse_info_dat(reader, selected_info_dat_path)

	reader.close()
	return {
		"ok": true,
		"archive_path": archive_path,
		"archive_file_name": archive_path.get_file(),
		"archive_size_bytes": int(FileAccess.get_file_as_bytes(archive_path).size()),
		"entry_count": entries.size(),
		"entries": entries,
		"info_dat_candidates": info_dat_candidates,
		"selected_info_dat_path": selected_info_dat_path,
		"parsed_info_dat": parsed_info_dat,
		"audio_file_candidates": audio_file_candidates,
		"cover_image_candidates": cover_image_candidates
	}

func _parse_info_dat(reader: ZIPReader, entry_path: String) -> Dictionary:
	var file_bytes: PackedByteArray = reader.read_file(entry_path)
	var parsed = JSON.parse_string(file_bytes.get_string_from_utf8())
	if parsed == null or not parsed is Dictionary:
		return {
			"path": entry_path,
			"parse_error": "Info.dat did not decode to a dictionary"
		}

	var difficulty_sets_payload = parsed.get("_difficultyBeatmapSets", parsed.get("difficultyBeatmapSets", []))
	var normalized_characteristics: Array = []
	var normalized_difficulties: Array = []
	for set_payload in difficulty_sets_payload:
		if not set_payload is Dictionary:
			continue
		var characteristic_name := str(set_payload.get("_beatmapCharacteristicName", set_payload.get("beatmapCharacteristicName", "")))
		var characteristic_difficulties: Array = []
		for difficulty_payload in set_payload.get("_difficultyBeatmaps", set_payload.get("difficultyBeatmaps", [])):
			if not difficulty_payload is Dictionary:
				continue
			var difficulty_entry := {
				"characteristic": characteristic_name,
				"difficulty": str(difficulty_payload.get("_difficulty", difficulty_payload.get("difficulty", ""))),
				"difficulty_rank": int(difficulty_payload.get("_difficultyRank", difficulty_payload.get("difficultyRank", 0))),
				"path": str(difficulty_payload.get("_beatmapFilename", difficulty_payload.get("beatmapFilename", ""))),
				"note_jump_movement_speed": float(difficulty_payload.get("_noteJumpMovementSpeed", difficulty_payload.get("noteJumpMovementSpeed", 0.0))),
				"note_jump_start_beat_offset": float(difficulty_payload.get("_noteJumpStartBeatOffset", difficulty_payload.get("noteJumpStartBeatOffset", 0.0)))
			}
			characteristic_difficulties.append(difficulty_entry)
			normalized_difficulties.append(difficulty_entry.duplicate(true))
		normalized_characteristics.append({
			"characteristic": characteristic_name,
			"difficulty_count": characteristic_difficulties.size(),
			"difficulties": characteristic_difficulties
		})

	return {
		"path": entry_path,
		"song_name": str(parsed.get("_songName", parsed.get("songName", ""))),
		"song_sub_name": str(parsed.get("_songSubName", parsed.get("songSubName", ""))),
		"song_author_name": str(parsed.get("_songAuthorName", parsed.get("songAuthorName", ""))),
		"level_author_name": str(parsed.get("_levelAuthorName", parsed.get("levelAuthorName", ""))),
		"song_filename": str(parsed.get("_songFilename", parsed.get("songFilename", ""))),
		"cover_image_filename": str(parsed.get("_coverImageFilename", parsed.get("coverImageFilename", ""))),
		"beats_per_minute": float(parsed.get("_beatsPerMinute", parsed.get("beatsPerMinute", 0.0))),
		"shuffle": float(parsed.get("_shuffle", parsed.get("shuffle", 0.0))),
		"shuffle_period": float(parsed.get("_shufflePeriod", parsed.get("shufflePeriod", 0.0))),
		"preview_start_time": float(parsed.get("_previewStartTime", parsed.get("previewStartTime", 0.0))),
		"preview_duration": float(parsed.get("_previewDuration", parsed.get("previewDuration", 0.0))),
		"song_time_offset": float(parsed.get("_songTimeOffset", parsed.get("songTimeOffset", 0.0))),
		"difficulty_count": normalized_difficulties.size(),
		"difficulties": normalized_difficulties,
		"characteristics": normalized_characteristics,
		"raw": parsed.duplicate(true)
	}

func _error_result(message: String, code: int = ERR_INVALID_DATA) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"category": "archive",
			"message": message,
			"code": code
		}
	}
