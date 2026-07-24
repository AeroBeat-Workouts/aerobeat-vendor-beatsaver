class_name BeatSaverBrowserTestbed
extends Control

const RESULT_CARD_SCENE = preload("res://scenes/beatsaver_result_card.tscn")
const RESULT_CARD_TARGET_WIDTH := 280
const RESULT_CARD_MAX_COLUMNS := 2
const RESULTS_GRID_GAP := 12
const PREVIEW_CACHE_ROOT := "user://beatsaver-preview-cache"

signal preview_request_finished(result: Dictionary)

@export var auto_bootstrap := true

@onready var _mode_option_button: OptionButton = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/ModeOptionButton
@onready var _query_line_edit: LineEdit = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/QueryLineEdit
@onready var _search_order_option_button: OptionButton = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/SearchOrderOptionButton
@onready var _genre_tags_menu_button: MenuButton = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/GenreTagsMenuButton
@onready var _difficulty_menu_button: MenuButton = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/DifficultyMenuButton
@onready var _refresh_button: Button = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/ControlsRow/RefreshButton
@onready var _results_summary_label: Label = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/StatusRow/ResultsSummaryLabel
@onready var _status_label: Label = $RootMargin/RootLayout/HeaderPanel/HeaderMargin/HeaderVBox/StatusRow/StatusLabel
@onready var _results_scroll: ScrollContainer = $RootMargin/RootLayout/BodyLayout/ResultsPanel/ResultsMargin/ResultsVBox/ResultsScroll
@onready var _results_grid: GridContainer = $RootMargin/RootLayout/BodyLayout/ResultsPanel/ResultsMargin/ResultsVBox/ResultsScroll/ResultsGrid
@onready var _detail_panel: PanelContainer = $RootMargin/RootLayout/BodyLayout/DetailPanel
@onready var _detail_cover_image = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailCoverImage
@onready var _detail_title_label: Label = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailTitleLabel
@onready var _detail_subtitle_label: Label = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailSubtitleLabel
@onready var _detail_metadata_label: RichTextLabel = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DetailMetadataLabel
@onready var _version_option_button: OptionButton = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/VersionRow/VersionOptionButton
@onready var _preview_button: Button = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/PreviewButton
@onready var _download_button: Button = $RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DownloadButton
@onready var _preview_audio_player: AudioStreamPlayer = $PreviewAudioPlayer
@onready var _preview_http_request: HTTPRequest = $PreviewHttpRequest

var state: BeatSaverTestbedState
var preview_stream_loader: Callable = Callable()
var preview_remote_fetcher: Callable = Callable()
var last_preview_cache_path: String = ""
var _pending_preview_url: String = ""
var _rendered_result_ids: PackedStringArray = []
var _load_more_requested: bool = false

func _ready() -> void:
	_setup_mode_picker()
	_setup_search_order_picker()
	_setup_filter_menus()
	_wire_ui()
	if state == null:
		state = BeatSaverTestbedState.new(BeatSaverVendorFacade.new(), "res://.artifacts")
	state.state_changed.connect(_render_state)
	_results_scroll.resized.connect(_on_results_scroll_resized)
	var vertical_scroll_bar := _results_scroll.get_v_scroll_bar()
	if vertical_scroll_bar != null and not vertical_scroll_bar.value_changed.is_connected(_on_results_scroll_value_changed):
		vertical_scroll_bar.value_changed.connect(_on_results_scroll_value_changed)
	if not _preview_http_request.request_completed.is_connected(_on_preview_request_completed):
		_preview_http_request.request_completed.connect(_on_preview_request_completed)
	_query_line_edit.text = state.remote_query_text
	_select_search_order(state.search_sort_order)
	_sync_filter_menus()
	_mode_option_button.select(0 if state.mode == "latest" else 1)
	if auto_bootstrap:
		state.refresh_active_mode()
	else:
		_render_state()

func _setup_mode_picker() -> void:
	_mode_option_button.clear()
	_mode_option_button.add_item("Latest")
	_mode_option_button.add_item("Search")

func _setup_search_order_picker() -> void:
	_search_order_option_button.clear()
	for label in ["Relevance", "Latest", "Rating"]:
		_search_order_option_button.add_item(label)

func _setup_filter_menus() -> void:
	_configure_multi_select_popup(_genre_tags_menu_button.get_popup())
	_configure_multi_select_popup(_difficulty_menu_button.get_popup())
	var genre_popup := _genre_tags_menu_button.get_popup()
	if not genre_popup.id_pressed.is_connected(_on_genre_tag_option_pressed):
		genre_popup.id_pressed.connect(_on_genre_tag_option_pressed)
	var difficulty_popup := _difficulty_menu_button.get_popup()
	if not difficulty_popup.id_pressed.is_connected(_on_difficulty_option_pressed):
		difficulty_popup.id_pressed.connect(_on_difficulty_option_pressed)

func _configure_multi_select_popup(popup: PopupMenu) -> void:
	popup.hide_on_checkable_item_selection = false
	popup.hide_on_item_selection = false
	popup.hide_on_state_item_selection = false

func _wire_ui() -> void:
	_mode_option_button.item_selected.connect(_on_mode_selected)
	_query_line_edit.text_submitted.connect(_on_query_submitted)
	_search_order_option_button.item_selected.connect(_on_search_order_selected)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_version_option_button.item_selected.connect(_on_version_selected)
	_preview_button.pressed.connect(_on_preview_pressed)
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

func _on_search_order_selected(index: int) -> void:
	state.search_sort_order = _search_order_value(index)
	if state.mode == "search":
		state.load_search(_query_line_edit.text)

func _on_refresh_pressed() -> void:
	if _mode_option_button.selected == 1:
		state.load_search(_query_line_edit.text)
		return
	state.load_latest()

func _on_genre_tag_option_pressed(item_id: int) -> void:
	var selected_tags := state.selected_genre_tags()
	var toggled_value := String(_genre_tags_menu_button.get_popup().get_item_metadata(item_id))
	if _packed_string_array_has(selected_tags, toggled_value):
		selected_tags = _packed_string_array_without(selected_tags, toggled_value)
	else:
		selected_tags.append(toggled_value)
	state.set_filters(selected_tags, state.selected_difficulties())

func _on_difficulty_option_pressed(item_id: int) -> void:
	var selected_difficulties := state.selected_difficulties()
	var toggled_value := String(_difficulty_menu_button.get_popup().get_item_metadata(item_id))
	if _packed_string_array_has(selected_difficulties, toggled_value):
		selected_difficulties = _packed_string_array_without(selected_difficulties, toggled_value)
	else:
		selected_difficulties.append(toggled_value)
	state.set_filters(state.selected_genre_tags(), selected_difficulties)

func _search_order_value(index: int) -> String:
	match index:
		1:
			return "latest"
		2:
			return "rating"
		_:
			return "relevance"

func _select_search_order(sort_order: String) -> void:
	var normalized := sort_order.strip_edges().to_lower()
	match normalized:
		"latest":
			_search_order_option_button.select(1)
		"rating":
			_search_order_option_button.select(2)
		_:
			_search_order_option_button.select(0)

func _sync_filter_menus() -> void:
	_rebuild_multi_select_popup(_genre_tags_menu_button, state.available_genre_tags(), state.selected_genre_tags())
	_rebuild_multi_select_popup(_difficulty_menu_button, state.available_difficulties(), state.selected_difficulties())
	_genre_tags_menu_button.text = _multi_select_button_text("Genres (BeatSaver tags)", state.selected_genre_tags(), func(value: String) -> String:
		return _display_genre_tag(value)
	)
	_difficulty_menu_button.text = _multi_select_button_text("Any Difficulty", state.selected_difficulties())

func _rebuild_multi_select_popup(button: MenuButton, options: PackedStringArray, selected_values: PackedStringArray) -> void:
	var popup := button.get_popup()
	popup.clear()
	for index in range(options.size()):
		var option_value := String(options[index])
		popup.add_check_item(_display_genre_tag(option_value) if button == _genre_tags_menu_button else option_value, index)
		popup.set_item_metadata(index, option_value)
		popup.set_item_checked(index, _packed_string_array_has(selected_values, option_value))

func _multi_select_button_text(empty_text: String, selected_values: PackedStringArray, formatter: Callable = Callable()) -> String:
	if selected_values.is_empty():
		return empty_text
	var labels := PackedStringArray()
	for value in selected_values:
		labels.append(String(formatter.call(value)) if formatter.is_valid() else String(value))
	if labels.size() <= 2:
		return ", ".join(labels)
	return "%d selected" % labels.size()

func _display_genre_tag(tag_value: String) -> String:
	var words := PackedStringArray()
	for raw_word in tag_value.replace("-", " ").split(" ", false):
		var word := String(raw_word).strip_edges()
		if word.is_empty():
			continue
		words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(words)

func _packed_string_array_has(values: PackedStringArray, target: String) -> bool:
	for value in values:
		if String(value) == target:
			return true
	return false

func _packed_string_array_without(values: PackedStringArray, target: String) -> PackedStringArray:
	var filtered := PackedStringArray()
	for value in values:
		if String(value) != target:
			filtered.append(String(value))
	return filtered

func _on_version_selected(index: int) -> void:
	if index < 0:
		return
	state.selected_version_identifier = str(_version_option_button.get_item_metadata(index))
	state._refresh_selected_package_truth()
	_render_state()

func _on_preview_pressed() -> void:
	await play_selected_preview()

func _on_download_pressed() -> void:
	await state.run_selected_version_action(self, state.selected_version_identifier)

func play_selected_preview() -> Dictionary:
	var preview_target: Dictionary = state.preview_selected_version()
	if not bool(preview_target.get("ok", false)):
		_render_state()
		return preview_target
	var target := String(preview_target.get("target", "")).strip_edges()
	var kind := String(preview_target.get("kind", "")).strip_edges()
	if kind.begins_with("local_"):
		return _play_preview_path(target, kind)
	return await _play_remote_preview(target, kind)

func _play_remote_preview(url: String, kind: String) -> Dictionary:
	var fetch_result: Dictionary = await _fetch_remote_preview(url)
	if not bool(fetch_result.get("ok", false)):
		return _set_preview_failure(kind, url, str(fetch_result.get("error", {}).get("message", "Failed to fetch remote preview audio.")), int(fetch_result.get("error", {}).get("code", ERR_CANT_CONNECT)))
	var cache_result := _cache_remote_preview(url, PackedStringArray(fetch_result.get("headers", PackedStringArray())), PackedByteArray(fetch_result.get("body", PackedByteArray())))
	if not bool(cache_result.get("ok", false)):
		return _set_preview_failure(kind, url, str(cache_result.get("error", {}).get("message", "Failed to cache remote preview audio.")), int(cache_result.get("error", {}).get("code", ERR_CANT_CREATE)))
	last_preview_cache_path = str(cache_result.get("cache_path", ""))
	var playback_result := _play_preview_path(last_preview_cache_path, kind)
	if bool(playback_result.get("ok", false)):
		playback_result["cache_path"] = last_preview_cache_path
		state.last_preview_result = playback_result.duplicate(true)
		state.emit_signal("state_changed")
	return playback_result

func _play_preview_path(path: String, kind: String) -> Dictionary:
	var normalized_path := _normalize_path(path)
	var stream := _load_audio_stream(normalized_path)
	if stream == null:
		return _set_preview_failure(kind, normalized_path, "Failed to decode preview audio for in-engine playback.", ERR_FILE_UNRECOGNIZED)
	_preview_audio_player.stop()
	_preview_audio_player.stream = stream
	_preview_audio_player.play()
	var result := {
		"ok": true,
		"kind": kind,
		"target": normalized_path,
		"error": {}
	}
	state.last_preview_result = result.duplicate(true)
	state.error_message = ""
	state.emit_signal("state_changed")
	return result

func _fetch_remote_preview(url: String) -> Dictionary:
	if preview_remote_fetcher.is_valid():
		var override_result = preview_remote_fetcher.call(url)
		return Dictionary(override_result).duplicate(true)
	if DisplayServer.get_name().to_lower() == "headless":
		return {"ok": false, "error": {"message": "Remote preview fetch is unavailable in headless mode.", "code": ERR_UNAVAILABLE}}
	if _preview_http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_preview_http_request.cancel_request()
	_pending_preview_url = url
	var request_error := _preview_http_request.request(url)
	if request_error != OK:
		return {"ok": false, "error": {"message": "Failed to request remote preview audio.", "code": request_error}}
	return await preview_request_finished

func _on_preview_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var payload := {
		"ok": result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and not body.is_empty(),
		"url": _pending_preview_url,
		"response_code": response_code,
		"headers": headers,
		"body": body,
		"error": {}
	}
	if not bool(payload.get("ok", false)):
		payload["error"] = {
			"message": "Remote preview request failed.",
			"code": result if result != HTTPRequest.RESULT_SUCCESS else response_code,
		}
	_pending_preview_url = ""
	emit_signal("preview_request_finished", payload)

func _cache_remote_preview(url: String, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	if body.is_empty():
		return {"ok": false, "error": {"message": "Remote preview audio response was empty.", "code": ERR_INVALID_DATA}}
	var extension := _preview_extension(url, headers)
	var cache_dir := ProjectSettings.globalize_path(PREVIEW_CACHE_ROOT)
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var cache_path := cache_dir.path_join("%s.%s" % [url.sha256_text(), extension])
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": {"message": "Failed to write cached remote preview audio.", "code": ERR_CANT_CREATE}}
	file.store_buffer(body)
	file.flush()
	file.close()
	return {"ok": true, "cache_path": cache_path}

func _preview_extension(url: String, headers: PackedStringArray) -> String:
	var content_type := _extract_header(headers, "content-type").to_lower()
	if content_type.contains("ogg"):
		return "ogg"
	if content_type.contains("mpeg") or content_type.contains("mp3"):
		return "mp3"
	if content_type.contains("wav") or content_type.contains("wave"):
		return "wav"
	var lower_url := url.to_lower()
	for extension in ["ogg", "mp3", "wav"]:
		if lower_url.ends_with(".%s" % extension):
			return extension
	return "mp3"

func _extract_header(headers: PackedStringArray, header_name: String) -> String:
	var prefix := "%s:" % header_name.to_lower()
	for line in headers:
		if line.to_lower().begins_with(prefix):
			return line.substr(line.find(":") + 1).strip_edges()
	return ""

func _load_audio_stream(path: String) -> AudioStream:
	if preview_stream_loader.is_valid():
		return preview_stream_loader.call(path)
	var lower_path := path.to_lower()
	if lower_path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if lower_path.ends_with(".mp3"):
		return AudioStreamMP3.load_from_file(path)
	if lower_path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	var resource = ResourceLoader.load(path, "AudioStream")
	return resource if resource is AudioStream else null

func _normalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _set_preview_failure(kind: String, target: String, message: String, code: int) -> Dictionary:
	_preview_audio_player.stop()
	var result := {
		"ok": false,
		"kind": kind,
		"target": target,
		"error": {"message": message, "code": code}
	}
	state.last_preview_result = result.duplicate(true)
	state.error_message = message
	state.emit_signal("state_changed")
	return result

func _render_state() -> void:
	_results_summary_label.text = _results_summary_text()
	_status_label.text = state.current_status_text()
	_query_line_edit.editable = not state.busy
	_search_order_option_button.disabled = state.busy or state.mode != "search"
	_genre_tags_menu_button.disabled = state.busy
	_difficulty_menu_button.disabled = state.busy
	_refresh_button.disabled = state.busy
	_sync_filter_menus()
	_download_button.disabled = state.action_button_disabled()
	_preview_button.disabled = not bool(state.selected_preview_target().get("ok", false)) or state.selected_map == null
	_update_results_grid_columns()
	_render_results_grid()
	_render_detail_panel()
	_maybe_request_more_results()

func _render_results_grid() -> void:
	var visible_result_ids := _visible_result_ids()
	if visible_result_ids != _rendered_result_ids:
		_rebuild_results_grid()
		_rendered_result_ids = visible_result_ids
		return
	for index in range(mini(_results_grid.get_child_count(), state.visible_results.size())):
		var card = _results_grid.get_child(index)
		var map_detail = state.visible_results[index]
		card.bind_map(map_detail)
		card.button_pressed = map_detail.map_id == state.selected_map_id

func _rebuild_results_grid() -> void:
	for child in _results_grid.get_children():
		child.queue_free()
	for map_detail in state.visible_results:
		var card = RESULT_CARD_SCENE.instantiate()
		card.bind_map(map_detail)
		card.button_pressed = map_detail.map_id == state.selected_map_id
		card.map_chosen.connect(_on_card_chosen)
		_results_grid.add_child(card)

func _visible_result_ids() -> PackedStringArray:
	var result_ids := PackedStringArray()
	for map_detail in state.visible_results:
		result_ids.append(String(map_detail.map_id))
	return result_ids

func _update_results_grid_columns() -> void:
	var available_width := maxf(_results_scroll.size.x, float(RESULT_CARD_TARGET_WIDTH))
	var computed_columns := int(floor((available_width + RESULTS_GRID_GAP) / float(RESULT_CARD_TARGET_WIDTH + RESULTS_GRID_GAP)))
	_results_grid.columns = clampi(computed_columns, 1, RESULT_CARD_MAX_COLUMNS)

func _render_detail_panel() -> void:
	_detail_panel.visible = state.selected_map != null
	if state.selected_map == null:
		_detail_title_label.text = "Select a BeatSaver result"
		_detail_subtitle_label.text = "Search or browse latest maps to inspect provider metadata."
		_detail_metadata_label.text = ""
		_detail_cover_image.set_image_url("")
		_version_option_button.clear()
		_preview_button.text = "Preview"
		_download_button.text = "Download"
		return
	var detail: Dictionary = state.selected_detail_dictionary()
	_detail_title_label.text = str(detail.get("detail_title", ""))
	_detail_subtitle_label.text = str(detail.get("detail_subtitle", ""))
	_detail_cover_image.set_image_url(str(detail.get("cover_image_url", "")))
	_detail_metadata_label.text = _build_detail_bbcode(detail)
	_rebuild_versions(detail)
	_preview_button.text = state.preview_button_text()
	_download_button.text = state.action_button_text()

func _rebuild_versions(_detail: Dictionary) -> void:
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
		state._refresh_selected_package_truth()
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
	var summary := "%d visible result%s (%d fetched)" % [state.visible_results.size(), "s" if state.visible_results.size() != 1 else "", state.all_results.size()]
	if state.mode == "search" and state.total_pages > 0:
		summary += " • page %d/%d" % [state.current_page + 1, state.total_pages]
	if state.can_load_more_search_results():
		summary += " • scroll for more"
	return summary

func _on_card_chosen(map_id: String) -> void:
	state.select_map(map_id)

func _on_results_scroll_resized() -> void:
	_update_results_grid_columns()
	_maybe_request_more_results()

func _on_results_scroll_value_changed(_value: float) -> void:
	_maybe_request_more_results()

func _maybe_request_more_results() -> void:
	if _load_more_requested or not state.can_load_more_search_results():
		return
	var vertical_scroll_bar := _results_scroll.get_v_scroll_bar()
	if vertical_scroll_bar == null:
		return
	var remaining := vertical_scroll_bar.max_value - vertical_scroll_bar.page - vertical_scroll_bar.value
	if remaining > 160.0:
		return
	_load_more_requested = true
	call_deferred("_load_more_results")

func _load_more_results() -> void:
	if not state.can_load_more_search_results():
		_load_more_requested = false
		return
	state.load_next_page()
	_load_more_requested = false
	call_deferred("_maybe_request_more_results")
