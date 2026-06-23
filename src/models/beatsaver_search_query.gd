class_name BeatSaverSearchQuery
extends RefCounted

const MAX_PAGE_SIZE := 100
const DEFAULT_PAGE_SIZE := 20

var text: String
var page: int
var page_size: int
var sort_order: String
var automapper = null
var tags: PackedStringArray

func _init(
	p_text: String = "",
	p_page: int = 0,
	p_page_size: int = DEFAULT_PAGE_SIZE,
	p_sort_order: String = "",
	p_automapper = null,
	p_tags: PackedStringArray = PackedStringArray()
) -> void:
	text = p_text.strip_edges()
	page = maxi(0, p_page)
	page_size = clampi(p_page_size, 1, MAX_PAGE_SIZE)
	sort_order = _sanitize_sort_order(p_sort_order)
	automapper = p_automapper if typeof(p_automapper) == TYPE_BOOL else null
	tags = p_tags

func to_query_parameters() -> Dictionary:
	var query := {
		"q": text,
		"pageSize": page_size
	}
	if not sort_order.is_empty():
		query["sortOrder"] = sort_order
	if typeof(automapper) == TYPE_BOOL:
		query["automapper"] = automapper
	if not tags.is_empty():
		query["tags"] = ",".join(tags)
	return query

func to_dictionary() -> Dictionary:
	return {
		"text": text,
		"page": page,
		"page_size": page_size,
		"sort_order": sort_order,
		"automapper": automapper,
		"tags": Array(tags)
	}

func _sanitize_sort_order(raw_sort_order: String) -> String:
	var candidate := raw_sort_order.strip_edges().to_lower()
	match candidate:
		"latest", "relevance", "rating", "curated":
			return candidate
		_:
			return ""
