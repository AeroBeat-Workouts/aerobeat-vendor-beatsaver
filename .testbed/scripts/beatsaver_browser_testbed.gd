class_name BeatSaverBrowserTestbed
extends Control

const BeatSaverVendorFacade = preload("res://../src/facade/beatsaver_vendor_facade.gd")
const BeatSaverTestbedState = preload("res://scripts/beatsaver_testbed_state.gd")
const RESULT_CARD_SCENE = preload("res://scenes/beatsaver_result_card.tscn")

@export var auto_bootstrap := true

@onready var _mode_option_button: OptionButton = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/ModeOptionButton
@onready var _query_line_edit: LineEdit = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/QueryLineEdit
@onready var _filter_line_edit: LineEdit = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/FilterLineEdit
@onready var _tag_filter_line_edit: LineEdit = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/TagFilterLineEdit
@onready var _refresh_button: Button = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/RefreshButton
@onready var _results_summary_label: Label = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/StatusRow/ResultsSummaryLabel
@onready var _status_label: Label = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/StatusRow/StatusLabel
@onready var _results_grid: GridContainer = $RootMargin/RootLayout/BodyLayout/ResultsPanel/ResultsMargin/ResultsVBox/ResultsScroll/ResultsGrid
@onready var _detail_panel: PanelContainer = $RootMargin/RootLayout/BodyLayout/DetailPanel
@onready var _detail_cover_image = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailCoverImage
@onready var _detail_title_label: Label = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailTitleLabel
@onready var _detail_subtitle_label: Label = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailSubtitleLabel
@onready var _detail_metadata_label: RichTextLabel = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailMetadataLabel
@onready var _version_option_button: OptionButton = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/VersionRow/VersionOptionButton
@onready var _download_button: Button = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DownloadButton

var state: BeatSaverTestbedState

func _ready() -> void:
	_setup_mode_picker()
	_wire_ui()
	if state == null:
		state = BeatSaverTestbedState.new(BeatSaverVendorFacade.new(), "res://.artifacts")
	state.state_changed.connect(_render_state)
	_query_line_edit.text = state.remote_query_text
	_filter_line_edit.text = state.local_filter_text
	_tag_filter_line_edit.text = state.tag_filter_text
	_mode_option_button.select(0 if state.mode == "latest" else 1)
	if auto_bootstrap:
		state.refresh_active_mode()
	else:
		_render_state()

func _setup_mode_picker() -> void:
	_mode_option_button.clear()
	_mode_option_button.add_item("Latest")
	_mode_option_button.add_item("Search")

func _wire_ui() -> void:
	_mode_option_button.item_selected.connect(_on_mode_selected)
	_query_line_edit.text_submitted.connect(_on_query_submitted)
	_filter_line_edit.text_changed.connect(_on_filter_changed)
	_tag_filter_line_edit.text_changed.connect(_on_tag_filter_changed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_version_option_button.item_selected.connect(_on_version_selected)
	_download_button.pressed.connect(_on_download_pressed)

func _on_mode_selected(index: int) -> void:
	state.mode = "latest" if index == 0 else "search"
	if state.mode == "latest":
		state.load_latest()
	else:
		state.load_search(_query_line_edit.text)

func _on_query_submitted(_value: String) -> void:
	state.load_search(_query_line_edit.text)
	_mode_option_button.select(1)

func _on_refresh_pressed() -> void:
	if _mode_option_button.selected == 1:
		state.load_search(_query_line_edit.text)
		return
	state.load_latest()

func _on_filter_changed(_value: String) -> void:
	state.set_filters(_filter_line_edit.text, _tag_filter_line_edit.text)

func _on_tag_filter_changed(_value: String) -> void:
	state.set_filters(_filter_line_edit.text, _tag_filter_line_edit.text)

func _on_version_selected(index: int) -> void:
	if index < 0:
		return
	state.selected_version_identifier = str(_version_option_button.get_item_metadata(index))
	_render_state()

func _on_download_pressed() -> void:
	state.stage_selected_version(state.selected_version_identifier)

func _render_state() -> void:
	_results_summary_label.text = _results_summary_text()
	_status_label.text = state.current_status_text()
	_query_line_edit.editable = not state.busy
	_refresh_button.disabled = state.busy
	_download_button.disabled = state.busy or state.selected_map == null
	_rebuild_results_grid()
	_render_detail_panel()

func _rebuild_results_grid() -> void:
	for child in _results_grid.get_children():
		child.queue_free()
	for map_detail in state.visible_results:
		var card = RESULT_CARD_SCENE.instantiate()
		card.bind_map(map_detail)
		card.button_pressed = map_detail.map_id == state.selected_map_id
		card.map_chosen.connect(_on_card_chosen)
		_results_grid.add_child(card)

func _render_detail_panel() -> void:
	_detail_panel.visible = state.selected_map != null
	if state.selected_map == null:
		_detail_title_label.text = "Select a BeatSaver result"
		_detail_subtitle_label.text = "Search or browse latest maps to inspect provider metadata."
		_detail_metadata_label.text = ""
		_detail_cover_image.set_image_url("")
		_version_option_button.clear()
		_download_button.text = "Stage Selected ZIP"
		return
	var detail: Dictionary = state.selected_detail_dictionary()
	_detail_title_label.text = str(detail.get("detail_title", ""))
	_detail_subtitle_label.text = str(detail.get("detail_subtitle", ""))
	_detail_cover_image.set_image_url(str(detail.get("cover_image_url", "")))
	_detail_metadata_label.text = _build_detail_bbcode(detail)
	_rebuild_versions(detail)
	_download_button.text = "Stage Selected ZIP to .testbed/.artifacts"

func _rebuild_versions(detail: Dictionary) -> void:
	_version_option_button.clear()
	var options := state.selected_version_options()
	var selected_index := -1
	for index in range(options.size()):
		var option: Dictionary = options[index]
		_version_option_button.add_item(str(option.get("label", "Version")))
		_version_option_button.set_item_metadata(index, option.get("id", ""))
		if str(option.get("id", "")) == state.selected_version_identifier:
			selected_index = index
	if selected_index < 0 and options.size() > 0:
		selected_index = 0
		state.selected_version_identifier = str(options[0].get("id", ""))
	if selected_index >= 0:
		_version_option_button.select(selected_index)

func _build_detail_bbcode(detail: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("[b]Map ID:[/b] %s" % str(detail.get("map_id", "")))
	lines.append("[b]Uploader:[/b] %s" % str(detail.get("uploader_name", "")))
	lines.append("[b]Song:[/b] %s" % str(detail.get("song_name", "")))
	lines.append("[b]Song Author:[/b] %s" % str(detail.get("song_author_name", "")))
	lines.append("[b]Level Author:[/b] %s" % str(detail.get("level_author_name", "")))
	lines.append("[b]BPM:[/b] %.2f" % float(detail.get("bpm", 0.0)))
	lines.append("[b]Duration:[/b] %.2f min" % float(detail.get("duration_minutes", 0.0)))
	lines.append("[b]Versions:[/b] %d" % int(detail.get("version_count", 0)))
	lines.append("[b]Primary Download:[/b] %s" % str(detail.get("primary_download_url", "")))
	lines.append("[b]Preview:[/b] %s" % str(detail.get("preview_audio_url", "")))
	lines.append("[b]Tags:[/b] %s" % ", ".join(PackedStringArray(detail.get("tags", []))))
	var stats: Dictionary = detail.get("stats", {})
	lines.append("[b]Stats:[/b] %d downloads • %d plays • %.2f score" % [int(stats.get("downloads", 0)), int(stats.get("plays", 0)), float(stats.get("score", 0.0))])
	var uploader: Dictionary = detail.get("uploader", {})
	if not str(uploader.get("avatar", "")).is_empty():
		lines.append("[b]Uploader Avatar:[/b] %s" % str(uploader.get("avatar", "")))
	if not str(detail.get("description", "")).is_empty():
		lines.append("\n[b]Description[/b]\n%s" % str(detail.get("description", "")))
	return "\n".join(lines)

func _results_summary_text() -> String:
	return "%d visible result%s (%d fetched)" % [state.visible_results.size(), "s" if state.visible_results.size() != 1 else "", state.all_results.size()]

func _on_card_chosen(map_id: String) -> void:
	state.select_map(map_id)
