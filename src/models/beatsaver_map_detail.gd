class_name BeatSaverMapDetail
extends RefCounted

const BeatSaverVersionRef = preload("res://../src/models/beatsaver_version_ref.gd")

var provider: String = "beatsaver"
var map_id: String
var map_key: String
var map_name: String
var description: String
var tags: PackedStringArray
var song_name: String
var song_sub_name: String
var song_author_name: String
var level_author_name: String
var bpm: float
var duration_seconds: int
var uploader: Dictionary
var stats: Dictionary
var versions: Array
var latest_version = null
var created_at: String
var updated_at: String
var uploaded_at: String
var last_published_at: String
var ranked: bool
var qualified: bool
var bl_ranked: bool
var bl_qualified: bool
var automapper: bool
var declared_ai: bool
var raw: Dictionary

func _init(payload: Dictionary = {}) -> void:
	map_id = str(payload.get("id", "")).to_upper()
	map_key = map_id
	map_name = str(payload.get("name", ""))
	description = str(payload.get("description", ""))
	tags = PackedStringArray(payload.get("tags", []))
	var metadata: Dictionary = payload.get("metadata", {})
	song_name = str(metadata.get("songName", ""))
	song_sub_name = str(metadata.get("songSubName", ""))
	song_author_name = str(metadata.get("songAuthorName", ""))
	level_author_name = str(metadata.get("levelAuthorName", ""))
	bpm = float(metadata.get("bpm", 0.0))
	duration_seconds = int(metadata.get("duration", 0))
	uploader = _normalize_uploader(payload.get("uploader", {}))
	stats = _normalize_stats(payload.get("stats", {}))
	versions = []
	for version_payload in payload.get("versions", []):
		if version_payload is Dictionary:
			versions.append(BeatSaverVersionRef.new(version_payload))
	latest_version = versions[0] if versions.size() > 0 else null
	created_at = str(payload.get("createdAt", ""))
	updated_at = str(payload.get("updatedAt", ""))
	uploaded_at = str(payload.get("uploaded", ""))
	last_published_at = str(payload.get("lastPublishedAt", ""))
	ranked = _coerce_bool(payload.get("ranked", false))
	qualified = _coerce_bool(payload.get("qualified", false))
	bl_ranked = _coerce_bool(payload.get("blRanked", false))
	bl_qualified = _coerce_bool(payload.get("blQualified", false))
	automapper = _coerce_bool(payload.get("automapper", false))
	declared_ai = _coerce_bool(payload.get("declaredAi", false))
	raw = payload.duplicate(true)

func to_dictionary() -> Dictionary:
	var normalized_versions: Array = []
	for version_ref in versions:
		normalized_versions.append(version_ref.to_dictionary())
	return {
		"provider": provider,
		"map_id": map_id,
		"map_key": map_key,
		"map_name": map_name,
		"description": description,
		"tags": Array(tags),
		"song_name": song_name,
		"song_sub_name": song_sub_name,
		"song_author_name": song_author_name,
		"level_author_name": level_author_name,
		"bpm": bpm,
		"duration_seconds": duration_seconds,
		"duration_minutes": duration_minutes(),
		"uploader": uploader.duplicate(true),
		"uploader_name": uploader_name(),
		"stats": stats.duplicate(true),
		"versions": normalized_versions,
		"version_count": versions.size(),
		"latest_version": latest_version.to_dictionary() if latest_version != null else {},
		"primary_hash": primary_hash(),
		"primary_download_url": primary_download_url(),
		"cover_image_url": cover_image_url(),
		"preview_audio_url": preview_audio_url(),
		"card_title": card_title(),
		"card_subtitle": card_subtitle(),
		"card_image_url": card_image_url(),
		"detail_title": detail_title(),
		"detail_subtitle": detail_subtitle(),
		"search_text": search_text(),
		"created_at": created_at,
		"updated_at": updated_at,
		"uploaded_at": uploaded_at,
		"last_published_at": last_published_at,
		"ranked": ranked,
		"qualified": qualified,
		"bl_ranked": bl_ranked,
		"bl_qualified": bl_qualified,
		"automapper": automapper,
		"declared_ai": declared_ai,
		"raw": raw.duplicate(true)
	}

func primary_hash() -> String:
	return latest_version.hash if latest_version != null else ""

func primary_download_url() -> String:
	return latest_version.download_url if latest_version != null else ""

func cover_image_url() -> String:
	return latest_version.cover_url if latest_version != null else ""

func preview_audio_url() -> String:
	return latest_version.preview_url if latest_version != null else ""

func uploader_name() -> String:
	return str(uploader.get("name", ""))

func card_title() -> String:
	if not song_name.is_empty():
		return song_name
	return map_name

func card_subtitle() -> String:
	var parts: PackedStringArray = []
	if not level_author_name.is_empty():
		parts.append(level_author_name)
	if not uploader_name().is_empty() and uploader_name() != level_author_name:
		parts.append(uploader_name())
	return " • ".join(parts)

func card_image_url() -> String:
	return cover_image_url()

func detail_title() -> String:
	return map_name if not map_name.is_empty() else card_title()

func detail_subtitle() -> String:
	var parts: PackedStringArray = []
	if not song_author_name.is_empty():
		parts.append(song_author_name)
	if not level_author_name.is_empty():
		parts.append(level_author_name)
	return " • ".join(parts)

func search_text() -> String:
	var parts: PackedStringArray = []
	for value in [map_name, song_name, song_sub_name, song_author_name, level_author_name, uploader_name(), map_id]:
		var text := str(value).strip_edges()
		if not text.is_empty():
			parts.append(text)
	for tag in tags:
		var normalized_tag := str(tag).strip_edges()
		if not normalized_tag.is_empty():
			parts.append(normalized_tag)
	return " ".join(parts)

func duration_minutes() -> float:
	if duration_seconds <= 0:
		return 0.0
	return float(duration_seconds) / 60.0

func find_version(identifier: String):
	var normalized := identifier.strip_edges()
	if normalized.is_empty():
		return latest_version
	var by_hash = find_version_by_hash(normalized)
	if by_hash != null:
		return by_hash
	return find_version_by_key(normalized)

func find_version_by_hash(version_hash: String):
	var normalized := version_hash.strip_edges().to_lower()
	for version_ref in versions:
		if version_ref.hash == normalized:
			return version_ref
	return null

func find_version_by_key(version_key: String):
	var normalized := version_key.strip_edges().to_upper()
	for version_ref in versions:
		if version_ref.key == normalized:
			return version_ref
	return null

func _normalize_uploader(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"name": str(payload.get("name", "")),
		"hash": str(payload.get("hash", "")),
		"type": str(payload.get("type", "")),
		"avatar": str(payload.get("avatar", "")),
		"playlist_url": str(payload.get("playlistUrl", "")),
		"admin": _coerce_bool(payload.get("admin", false)),
		"curator": _coerce_bool(payload.get("curator", false)),
		"senior_curator": _coerce_bool(payload.get("seniorCurator", false))
	}

func _normalize_stats(payload: Dictionary) -> Dictionary:
	return {
		"downloads": int(payload.get("downloads", 0)),
		"plays": int(payload.get("plays", 0)),
		"upvotes": int(payload.get("upvotes", 0)),
		"downvotes": int(payload.get("downvotes", 0)),
		"score": float(payload.get("score", 0.0)),
		"sentiment": float(payload.get("sentiment", 0.0)),
		"reviews": int(payload.get("reviews", 0))
	}

func _coerce_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	var normalized := str(value).strip_edges().to_lower()
	return normalized in ["true", "1", "yes"]
