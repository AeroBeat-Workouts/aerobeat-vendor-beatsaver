class_name BeatSaverVersionRef
extends RefCounted

const BeatSaverDifficultyRef = preload("res://../src/models/beatsaver_difficulty_ref.gd")

var hash: String
var key: String
var state: String
var created_at: String
var download_url: String
var cover_url: String
var preview_url: String
var sage_score: float
var difficulties: Array
var raw: Dictionary

func _init(payload: Dictionary = {}) -> void:
	hash = str(payload.get("hash", "")).to_lower()
	key = str(payload.get("key", "")).to_upper()
	state = str(payload.get("state", ""))
	created_at = str(payload.get("createdAt", ""))
	download_url = str(payload.get("downloadURL", ""))
	cover_url = str(payload.get("coverURL", ""))
	preview_url = str(payload.get("previewURL", ""))
	sage_score = float(payload.get("sageScore", 0.0))
	difficulties = []
	for difficulty_payload in payload.get("diffs", []):
		if difficulty_payload is Dictionary:
			difficulties.append(BeatSaverDifficultyRef.new(difficulty_payload))
	raw = payload.duplicate(true)

func to_dictionary() -> Dictionary:
	var normalized_difficulties: Array = []
	for difficulty_ref in difficulties:
		normalized_difficulties.append(difficulty_ref.to_dictionary())
	return {
		"hash": hash,
		"key": key,
		"state": state,
		"created_at": created_at,
		"download_url": download_url,
		"cover_url": cover_url,
		"preview_url": preview_url,
		"sage_score": sage_score,
		"difficulties": normalized_difficulties,
		"raw": raw.duplicate(true)
	}
