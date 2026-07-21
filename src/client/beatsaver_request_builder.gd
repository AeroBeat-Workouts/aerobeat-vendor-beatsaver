class_name BeatSaverRequestBuilder
extends RefCounted

const BeatSaverSearchQuery = preload("../models/beatsaver_search_query.gd")
const DEFAULT_BASE_URL := "https://api.beatsaver.com"
const ALLOWED_LATEST_SORTS := ["FIRST_PUBLISHED", "UPDATED", "LAST_PUBLISHED", "CREATED", "CURATED"]

var _base_url: String

func _init(base_url: String = DEFAULT_BASE_URL) -> void:
	_base_url = base_url.rstrip("/")

func build_search_request(query: BeatSaverSearchQuery) -> Dictionary:
	assert(query != null)
	return _build_get_request("/search/text/%d" % query.page, query.to_query_parameters())

func build_map_detail_by_id_request(map_id: String) -> Dictionary:
	return _build_get_request("/maps/id/%s" % _sanitize_path_value(map_id), {})

func build_map_detail_by_hash_request(map_hash: String) -> Dictionary:
	return _build_get_request("/maps/hash/%s" % _sanitize_path_value(map_hash).to_lower(), {})

func build_latest_maps_request(options: Dictionary = {}) -> Dictionary:
	var query := {}
	var page_size := int(options.get("page_size", options.get("pageSize", 20)))
	query["pageSize"] = clampi(page_size, 1, 100)
	var before := str(options.get("before", "")).strip_edges()
	if not before.is_empty():
		query["before"] = before
	var after := str(options.get("after", "")).strip_edges()
	if not after.is_empty():
		query["after"] = after
	var sort := _sanitize_latest_sort(str(options.get("sort", "")))
	if not sort.is_empty():
		query["sort"] = sort
	if typeof(options.get("automapper", null)) == TYPE_BOOL:
		query["automapper"] = options.get("automapper", false)
	return _build_get_request("/maps/latest", query)

func _build_get_request(path: String, query: Dictionary) -> Dictionary:
	return {
		"method": "GET",
		"path": path,
		"query": query,
		"headers": {"Accept": "application/json"},
		"expects": "json",
		"base_url": _base_url
	}

func _sanitize_path_value(raw_value: String) -> String:
	var sanitized := raw_value.strip_edges().uri_encode()
	assert(not sanitized.is_empty())
	return sanitized

func _sanitize_latest_sort(raw_value: String) -> String:
	var candidate := raw_value.strip_edges().to_upper()
	return candidate if ALLOWED_LATEST_SORTS.has(candidate) else ""
