class_name BeatSaverResultCard
extends Button

const BeatSaverMapDetail = preload("res://../src/models/beatsaver_map_detail.gd")

signal map_chosen(map_id: String)

var map_detail: BeatSaverMapDetail

func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_mode = Control.FOCUS_ALL
	_apply_map_detail()

func bind_map(detail: BeatSaverMapDetail) -> void:
	map_detail = detail
	if is_node_ready():
		_apply_map_detail()

func _apply_map_detail() -> void:
	var cover_image = get_node_or_null("Margin/VBox/CoverImage")
	var title_label = get_node_or_null("Margin/VBox/TitleLabel")
	var subtitle_label = get_node_or_null("Margin/VBox/SubtitleLabel")
	var tagline_label = get_node_or_null("Margin/VBox/TaglineLabel")
	if cover_image == null or title_label == null or subtitle_label == null or tagline_label == null:
		return
	if map_detail == null:
		title_label.text = "No map"
		subtitle_label.text = ""
		tagline_label.text = ""
		cover_image.set_image_url("")
		return
	title_label.text = map_detail.card_title()
	subtitle_label.text = map_detail.card_subtitle()
	var tagline_parts: PackedStringArray = []
	if not map_detail.map_id.is_empty():
		tagline_parts.append("#%s" % map_detail.map_id)
	if map_detail.latest_version != null:
		tagline_parts.append("%d version%s" % [map_detail.versions.size(), "s" if map_detail.versions.size() != 1 else ""])
	if map_detail.duration_seconds > 0:
		tagline_parts.append("%d sec" % map_detail.duration_seconds)
	tagline_label.text = " • ".join(tagline_parts)
	cover_image.set_image_url(map_detail.card_image_url())
	tooltip_text = "%s\n%s" % [map_detail.detail_title(), map_detail.search_text()]

func _on_pressed() -> void:
	if map_detail == null:
		return
	emit_signal("map_chosen", map_detail.map_id)
