class_name BeatSaverDifficultyRef
extends RefCounted

var characteristic: String
var difficulty: String
var stars: float
var notes: int
var bombs: int
var obstacles: int
var njs: float
var nps: float
var length: int
var seconds: float
var environment: String
var chroma: bool
var cinema: bool
var mapping_extensions: bool
var raw: Dictionary

func _init(payload: Dictionary = {}) -> void:
	characteristic = str(payload.get("characteristic", ""))
	difficulty = str(payload.get("difficulty", ""))
	stars = float(payload.get("stars", 0.0))
	notes = int(payload.get("notes", 0))
	bombs = int(payload.get("bombs", 0))
	obstacles = int(payload.get("obstacles", 0))
	njs = float(payload.get("njs", 0.0))
	nps = float(payload.get("nps", 0.0))
	length = int(payload.get("length", 0))
	seconds = float(payload.get("seconds", 0.0))
	environment = str(payload.get("environment", ""))
	chroma = payload.get("chroma", false)
	cinema = payload.get("cinema", false)
	mapping_extensions = payload.get("me", false)
	raw = payload.duplicate(true)

func to_dictionary() -> Dictionary:
	return {
		"characteristic": characteristic,
		"difficulty": difficulty,
		"stars": stars,
		"notes": notes,
		"bombs": bombs,
		"obstacles": obstacles,
		"njs": njs,
		"nps": nps,
		"length": length,
		"seconds": seconds,
		"environment": environment,
		"chroma": chroma,
		"cinema": cinema,
		"mapping_extensions": mapping_extensions,
		"raw": raw.duplicate(true)
	}
