class_name BeatSaverTestbedState
extends RefCounted

const BeatSaverVendorFacade = preload("res://../src/facade/beatsaver_vendor_facade.gd")
const BeatSaverSearchQuery = preload("res://../src/models/beatsaver_search_query.gd")

signal state_changed

var facade
var artifact_root: String
var mode: String = "latest"
var remote_query_text: String = "fitbeat"
var local_filter_text: String = ""
var tag_filter_text: String = ""
var page_size: int = 12
var include_automapper = null
var latest_sort: String = "latest"
var search_sort_order: String = "relevance"
var all_results: Array = []
var visible_results: Array = []
var selected_map = null
var selected_map_id: String = ""
var selected_version_identifier: String = ""
var last_collection_response: Dictionary = {}
var last_download_result: Dictionary = {}
var error_message: String = ""
var busy: bool = false

func _init(p_facade = null, p_artifact_root: String = "res://.artifacts") -> void:
	facade = p_facade if p_facade != null else BeatSaverVendorFacade.new()
	artifact_root = p_artifact_root

func load_search(query_text: String = "", page: int = 0) -> Dictionary:
	mode = "search"
	remote_query_text = query_text.strip_edges() if not query_text.is_empty() else remote_query_text
	busy = true
	error_message = ""
	emit_signal("state_changed")
	var response: Dictionary = facade.search_maps(BeatSaverSearchQuery.new(remote_query_text, page, page_size, search_sort_order, include_automapper))
	busy = false
	return _consume_collection_response(response)

func load_latest() -> Dictionary:
	mode = "latest"
	busy = true
	error_message = ""
	emit_signal("state_changed")
	var response: Dictionary = facade.list_latest_maps({
		"page_size": page_size,
		"sort": latest_sort,
		"automapper": include_automapper
	})
	busy = false
	return _consume_collection_response(response)

func refresh_active_mode() -> Dictionary:
	if mode == "search":
		return load_search(remote_query_text)
	return load_latest()

func set_filters(text_filter: String, tag_filter: String = "") -> void:
	local_filter_text = text_filter.strip_edges()
	tag_filter_text = tag_filter.strip_edges() if not tag_filter.is_empty() else ""
	_rebuild_visible_results()
	emit_signal("state_changed")

func select_map(map_id: String) -> Dictionary:
	var normalized_id := map_id.strip_edges().to_upper()
	if normalized_id.is_empty():
		selected_map = null
		selected_map_id = ""
		selected_version_identifier = ""
		emit_signal("state_changed")
		return {"ok": true, "data": null}
	busy = true
	error_message = ""
	emit_signal("state_changed")
	var response: Dictionary = facade.fetch_map_detail_by_id(normalized_id)
	busy = false
	if not response.get("ok", false):
		error_message = str(response.get("error", {}).get("message", "Failed to load BeatSaver map detail."))
		emit_signal("state_changed")
		return response
	selected_map = response.get("data", null)
	selected_map_id = normalized_id
	selected_version_identifier = selected_map.primary_hash() if selected_map != null else ""
	error_message = ""
	emit_signal("state_changed")
	return response

func stage_selected_version(version_identifier: String = "") -> Dictionary:
	if selected_map == null:
		last_download_result = {
			"ok": false,
			"error": {"message": "Select a BeatSaver result before staging an artifact."}
		}
		error_message = str(last_download_result.get("error", {}).get("message", "Select a BeatSaver result before staging an artifact."))
		emit_signal("state_changed")
		return last_download_result
	var effective_identifier := version_identifier.strip_edges()
	if effective_identifier.is_empty():
		effective_identifier = selected_version_identifier
	busy = true
	error_message = ""
	emit_signal("state_changed")
	last_download_result = facade.stage_selected_version_artifact(selected_map, effective_identifier, artifact_root)
	busy = false
	if last_download_result.get("ok", false):
		selected_version_identifier = effective_identifier if not effective_identifier.is_empty() else selected_map.primary_hash()
	else:
		error_message = str(last_download_result.get("error", {}).get("message", "Failed to stage the selected BeatSaver artifact."))
	emit_signal("state_changed")
	return last_download_result

func visible_result_count() -> int:
	return visible_results.size()

func selected_detail_dictionary() -> Dictionary:
	if selected_map == null:
		return {}
	return selected_map.to_dictionary()

func selected_version_options() -> Array:
	var options: Array = []
	if selected_map == null:
		return options
	for version_ref in selected_map.versions:
		var diff_labels: PackedStringArray = []
		for difficulty in version_ref.difficulties:
			var difficulty_name := str(difficulty.difficulty)
			var characteristic := str(difficulty.characteristic)
			if characteristic.is_empty():
				diff_labels.append(difficulty_name)
			else:
				diff_labels.append("%s/%s" % [characteristic, difficulty_name])
		options.append({
			"id": version_ref.hash,
			"key": version_ref.key,
			"label": "%s • %s • %d diff%s" % [version_ref.key if not version_ref.key.is_empty() else version_ref.hash.substr(0, min(version_ref.hash.length(), 8)), version_ref.hash.substr(0, min(version_ref.hash.length(), 8)), version_ref.difficulties.size(), "s" if version_ref.difficulties.size() != 1 else ""],
			"download_url": version_ref.download_url,
			"cover_url": version_ref.cover_url,
			"preview_url": version_ref.preview_url,
			"difficulties": diff_labels
		})
	return options

func current_status_text() -> String:
	if busy:
		return "Loading BeatSaver data…"
	if not error_message.is_empty():
		return error_message
	if last_download_result.get("ok", false):
		var manifest_path := str(last_download_result.get("data", {}).get("manifest", {}).get("manifest_path", ""))
		if not manifest_path.is_empty():
			return "Staged archive + manifest at %s" % manifest_path
		return "Staged BeatSaver artifact."
	if last_collection_response.get("ok", false):
		return "%d result%s ready." % [visible_results.size(), "s" if visible_results.size() != 1 else ""]
	return "Ready."

func _consume_collection_response(response: Dictionary) -> Dictionary:
	last_collection_response = response
	if not response.get("ok", false):
		all_results.clear()
		visible_results.clear()
		selected_map = null
		selected_map_id = ""
		selected_version_identifier = ""
		error_message = str(response.get("error", {}).get("message", "BeatSaver request failed."))
		emit_signal("state_changed")
		return response
	all_results = response.get("data", {}).get("maps", [])
	error_message = ""
	last_download_result = {}
	_rebuild_visible_results()
	if selected_map_id.is_empty() and visible_results.size() > 0:
		selected_map_id = visible_results[0].map_id
		selected_map = visible_results[0]
		selected_version_identifier = selected_map.primary_hash()
	elif not _visible_results_contain(selected_map_id):
		selected_map = null
		selected_map_id = ""
		selected_version_identifier = ""
	emit_signal("state_changed")
	return response

func _rebuild_visible_results() -> void:
	visible_results.clear()
	for map_detail in all_results:
		if _matches_filters(map_detail):
			visible_results.append(map_detail)

func _matches_filters(map_detail) -> bool:
	if map_detail == null:
		return false
	var text_filter := local_filter_text.to_lower()
	if not text_filter.is_empty() and not map_detail.search_text().to_lower().contains(text_filter):
		return false
	var normalized_tag_filter := tag_filter_text.to_lower()
	if not normalized_tag_filter.is_empty():
		var tag_match := false
		for tag in map_detail.tags:
			if str(tag).to_lower().contains(normalized_tag_filter):
				tag_match = true
				break
		if not tag_match:
			return false
	return true

func _visible_results_contain(map_id: String) -> bool:
	var normalized_id := map_id.strip_edges().to_upper()
	for map_detail in visible_results:
		if map_detail.map_id == normalized_id:
			return true
	return false
