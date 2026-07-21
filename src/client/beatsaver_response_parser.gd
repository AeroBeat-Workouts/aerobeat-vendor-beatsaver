class_name BeatSaverResponseParser
extends RefCounted

const BeatSaverMapDetail = preload("../models/beatsaver_map_detail.gd")

func parse_map_detail(payload: Dictionary) -> BeatSaverMapDetail:
	return BeatSaverMapDetail.new(payload)

func parse_search_response(payload: Dictionary) -> Dictionary:
	return _parse_map_collection(payload, "search")

func parse_latest_response(payload: Dictionary) -> Dictionary:
	return _parse_map_collection(payload, "latest")

func _parse_map_collection(payload: Dictionary, source: String) -> Dictionary:
	var docs: Array = []
	for raw_doc in payload.get("docs", []):
		if raw_doc is Dictionary:
			docs.append(parse_map_detail(raw_doc))
	var info: Dictionary = payload.get("info", {}) if payload.get("info", {}) is Dictionary else {}
	return {
		"source": source,
		"maps": docs,
		"count": docs.size(),
		"page": int(info.get("page", 0)),
		"pages": int(info.get("pages", 0)),
		"total": int(info.get("total", docs.size())),
		"duration_seconds": float(info.get("duration", 0.0)),
		"raw": payload.duplicate(true)
	}
