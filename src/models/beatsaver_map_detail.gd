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
		"uploader": uploader.duplicate(true),
		"stats": stats.duplicate(true),
		"versions": normalized_versions,
		"latest_version": latest_version.to_dictionary() if latest_version != null else {},
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
