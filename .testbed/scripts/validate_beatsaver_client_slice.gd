extends SceneTree

const BeatSaverPackageFetcher = preload("res://../src/acquisition/beatsaver_package_fetcher.gd")
const BeatSaverVendorFacade = preload("res://../src/facade/beatsaver_vendor_facade.gd")
const BeatSaverBrowserTestbed = preload("res://scripts/beatsaver_browser_testbed.gd")
const BeatSaverTestbedState = preload("res://scripts/beatsaver_testbed_state.gd")
const BeatSaverHttpClient = preload("res://../src/client/beatsaver_http_client.gd")
const BeatSaverRequestBuilder = preload("res://../src/client/beatsaver_request_builder.gd")
const BeatSaverResponseParser = preload("res://../src/client/beatsaver_response_parser.gd")
const BeatSaverSearchQuery = preload("res://../src/models/beatsaver_search_query.gd")

const BROWSER_SCENE = preload("res://scenes/beatsaver_browser_testbed.tscn")
const FIXTURE_DETAIL_PATH := "res://../assets/fixtures/beatsaver_api/map_detail_id_1.json"
const FIXTURE_SEARCH_PATH := "res://../assets/fixtures/beatsaver_api/search_fitbeat_page_0.json"
const FIXTURE_LATEST_PATH := "res://../assets/fixtures/beatsaver_api/latest_page_size_2.json"
const FIXTURE_PACKAGE_PATH := "res://fixtures/packages/synthetic_training_pack.zip"
const VALIDATION_ARTIFACT_ROOT := "res://.artifacts/validation"
const VALIDATION_UI_ARTIFACT_ROOT := "res://.artifacts/validation_ui"

class FakeBeatSaverFacade:
	extends RefCounted

	var _parser: BeatSaverResponseParser
	var _search_payload: Dictionary
	var _latest_payload: Dictionary
	var _detail_payload: Dictionary
	var _detail_by_id := {}
	var _staging_facade: BeatSaverVendorFacade
	var search_calls: int = 0
	var latest_calls: int = 0
	var detail_calls: int = 0
	var stage_calls: int = 0

	func _init(parser: BeatSaverResponseParser, search_payload: Dictionary, latest_payload: Dictionary, detail_payload: Dictionary, package_fetcher: BeatSaverPackageFetcher) -> void:
		_parser = parser
		_search_payload = search_payload
		_latest_payload = latest_payload
		_detail_payload = detail_payload
		for doc in search_payload.get("docs", []):
			if doc is Dictionary:
				_detail_by_id[str(doc.get("id", "")).to_upper()] = doc
		for doc in latest_payload.get("docs", []):
			if doc is Dictionary:
				_detail_by_id[str(doc.get("id", "")).to_upper()] = doc
		_detail_by_id[str(detail_payload.get("id", "")).to_upper()] = detail_payload
		_staging_facade = BeatSaverVendorFacade.new(null, null, _parser, package_fetcher)

	func search_maps(query: BeatSaverSearchQuery, _options: Dictionary = {}) -> Dictionary:
		search_calls += 1
		var parsed := _parser.parse_search_response(_search_payload)
		if not query.text.is_empty():
			var filtered_maps: Array = []
			for map_detail in parsed.get("maps", []):
				if map_detail.search_text().to_lower().contains(query.text.to_lower()):
					filtered_maps.append(map_detail)
			parsed["maps"] = filtered_maps
			parsed["count"] = filtered_maps.size()
		return {"ok": true, "data": parsed}

	func fetch_map_detail_by_id(map_id: String, _options: Dictionary = {}) -> Dictionary:
		detail_calls += 1
		var payload: Dictionary = _detail_by_id.get(map_id.strip_edges().to_upper(), _detail_payload)
		return {"ok": true, "data": _parser.parse_map_detail(payload)}

	func fetch_map_detail_by_hash(map_hash: String, _options: Dictionary = {}) -> Dictionary:
		return fetch_map_detail_by_id(map_hash, _options)

	func list_latest_maps(_options: Dictionary = {}) -> Dictionary:
		latest_calls += 1
		return {"ok": true, "data": _parser.parse_latest_response(_latest_payload)}

	func stage_selected_version_artifact(map_detail, version_selector: Variant = null, staging_root: String = "res://.artifacts", options: Dictionary = {}) -> Dictionary:
		stage_calls += 1
		return _staging_facade.stage_selected_version_artifact(map_detail, version_selector, staging_root, options)

var _failure_count := 0

func _init() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var parser := BeatSaverResponseParser.new()
	var builder := BeatSaverRequestBuilder.new()
	_validate_request_builder(builder)
	_validate_parser(parser)
	_validate_facade()
	_validate_acquisition(parser)
	await _validate_testbed_state_and_scene(parser)
	if _failure_count > 0:
		printerr("BeatSaver client/testbed validation failed with %d issue(s)." % _failure_count)
		quit(1)
		return
	print("BeatSaver client/testbed validation passed.")
	quit(0)

func _validate_request_builder(builder: BeatSaverRequestBuilder) -> void:
	var search_query := BeatSaverSearchQuery.new("fitbeat", 2, 10, "latest", false)
	var search_request := builder.build_search_request(search_query)
	_assert(search_request.path == "/search/text/2", "search path should target page 2")
	_assert(search_request.query.get("q", "") == "fitbeat", "search query should include text")
	_assert(int(search_request.query.get("pageSize", 0)) == 10, "search pageSize should be preserved")
	_assert(search_request.query.get("sortOrder", "") == "latest", "search sort order should be preserved")
	_assert(search_request.query.get("automapper", true) == false, "search automapper should be preserved")

	var detail_request := builder.build_map_detail_by_id_request("1")
	_assert(detail_request.path == "/maps/id/1", "detail request should target id endpoint")

	var hash_request := builder.build_map_detail_by_hash_request("FDA568FC27C20D21F8DC6F3709B49B5CC96723BE")
	_assert(hash_request.path == "/maps/hash/fda568fc27c20d21f8dc6f3709b49b5cc96723be", "hash request should normalize lower-case hash path")

	var latest_request := builder.build_latest_maps_request({"page_size": 2, "sort": "updated", "automapper": false})
	_assert(latest_request.path == "/maps/latest", "latest request should target latest endpoint")
	_assert(int(latest_request.query.get("pageSize", 0)) == 2, "latest request should preserve page size")
	_assert(latest_request.query.get("sort", "") == "UPDATED", "latest request should normalize sort enum")

func _validate_parser(parser: BeatSaverResponseParser) -> void:
	var detail := parser.parse_map_detail(_read_json(FIXTURE_DETAIL_PATH))
	_assert(detail.map_id == "1", "detail fixture should parse map id")
	_assert(detail.map_name == "succducc - me & u", "detail fixture should parse map name")
	_assert(detail.song_author_name == "", "detail fixture should parse song author")
	_assert(detail.level_author_name == "succducc", "detail fixture should parse level author")
	_assert(detail.primary_hash() == "fda568fc27c20d21f8dc6f3709b49b5cc96723be", "detail fixture should parse primary hash")
	_assert(detail.latest_version.download_url.begins_with("https://"), "detail fixture should expose version download URL")
	_assert(detail.latest_version.cover_url.begins_with("https://"), "detail fixture should expose version cover URL")
	_assert(detail.latest_version.preview_url.begins_with("https://"), "detail fixture should expose version preview URL")
	_assert(detail.uploader.get("name", "") == "datkami", "detail fixture should parse uploader")
	_assert(detail.versions.size() > 0, "detail fixture should parse at least one version")
	_assert(detail.latest_version.difficulties.size() > 0, "detail fixture should parse difficulty summaries")
	_assert(detail.card_title() == "me & u", "detail fixture should expose card title for catalog UI")
	_assert(detail.card_image_url().begins_with("https://"), "detail fixture should expose card image URL for catalog UI")
	_assert(detail.detail_title() == "succducc - me & u", "detail fixture should expose detail title for side panel UI")
	_assert(detail.primary_download_url().begins_with("https://"), "detail fixture should expose primary download URL for later CTA seam")
	_assert(detail.search_text().contains("datkami"), "detail fixture should expose flattened search/filter text")
	_assert(detail.find_version(detail.primary_hash()) != null, "detail fixture should resolve version by hash")
	var detail_dict := detail.to_dictionary()
	_assert(detail_dict.get("card_title", "") == "me & u", "detail dictionary should include card title")
	_assert(detail_dict.get("cover_image_url", "").begins_with("https://"), "detail dictionary should include cover image URL")

	var search_result := parser.parse_search_response(_read_json(FIXTURE_SEARCH_PATH))
	_assert(int(search_result.get("count", 0)) == 2, "search fixture should parse trimmed document count")
	_assert(int(search_result.get("pages", 0)) >= 1, "search fixture should parse page metadata")

	var latest_result := parser.parse_latest_response(_read_json(FIXTURE_LATEST_PATH))
	_assert(int(latest_result.get("count", 0)) == 2, "latest fixture should parse trimmed document count")

func _validate_facade() -> void:
	var request_log: Array = []
	var fixture_detail := _read_json(FIXTURE_DETAIL_PATH)
	var fixture_search := _read_json(FIXTURE_SEARCH_PATH)
	var fixture_latest := _read_json(FIXTURE_LATEST_PATH)
	var http_client := BeatSaverHttpClient.new(func(request: Dictionary, _options: Dictionary) -> Dictionary:
		request_log.append(request.url)
		if request.path.begins_with("/search/text/"):
			return {"status_code": 200, "headers": {"Content-Type": "application/json"}, "payload": fixture_search}
		if request.path == "/maps/id/1":
			return {"status_code": 200, "headers": {"Content-Type": "application/json"}, "payload": fixture_detail}
		if request.path == "/maps/hash/fda568fc27c20d21f8dc6f3709b49b5cc96723be":
			return {"status_code": 200, "headers": {"Content-Type": "application/json"}, "payload": fixture_detail}
		if request.path == "/maps/latest":
			return {"status_code": 200, "headers": {"Content-Type": "application/json"}, "payload": fixture_latest}
		return {"status_code": 404, "headers": {"Content-Type": "application/json"}, "payload": {"message": "missing fixture"}}
	)
	var facade := BeatSaverVendorFacade.new(http_client)

	var search_result := facade.search_maps(BeatSaverSearchQuery.new("fitbeat", 0, 2))
	_assert(search_result.ok, "facade search should succeed")
	_assert(search_result.data.maps.size() == 2, "facade search should return normalized maps")

	var detail_result := facade.fetch_map_detail_by_id("1")
	_assert(detail_result.ok, "facade detail-by-id should succeed")
	_assert(detail_result.data.map_name == "succducc - me & u", "facade detail-by-id should return normalized detail")

	var hash_result := facade.fetch_map_detail_by_hash("fda568fc27c20d21f8dc6f3709b49b5cc96723be")
	_assert(hash_result.ok, "facade detail-by-hash should succeed")
	_assert(hash_result.data.primary_hash() == "fda568fc27c20d21f8dc6f3709b49b5cc96723be", "facade detail-by-hash should preserve hash")

	var latest_result := facade.list_latest_maps({"page_size": 2})
	_assert(latest_result.ok, "facade latest listing should succeed")
	_assert(latest_result.data.maps.size() == 2, "facade latest listing should return normalized maps")

	_assert(request_log.size() == 4, "facade validation should execute four provider calls")

func _validate_acquisition(parser: BeatSaverResponseParser) -> void:
	var map_detail = parser.parse_map_detail(_read_json(FIXTURE_DETAIL_PATH))
	var validation_root := ProjectSettings.globalize_path(VALIDATION_ARTIFACT_ROOT)
	_cleanup_directory(validation_root)
	var package_fetcher := _build_fixture_package_fetcher()
	var facade := BeatSaverVendorFacade.new(null, null, parser, package_fetcher)
	var staged := facade.stage_selected_version_artifact(map_detail, map_detail.primary_hash(), VALIDATION_ARTIFACT_ROOT)
	_assert(staged.get("ok", false), "acquisition seam should stage the selected version artifact")
	if not staged.get("ok", false):
		return
	var stage: Dictionary = staged.data.stage
	var archive: Dictionary = staged.data.archive
	var manifest: Dictionary = staged.data.manifest
	_assert(FileAccess.file_exists(str(stage.get("archive_path", ""))), "staged archive should exist on disk")
	_assert(int(archive.get("entry_count", 0)) == 5, "synthetic archive should expose five entries")
	_assert(manifest.get("map_id", "") == "1", "manifest should preserve map id")
	_assert(manifest.get("version_hash", "") == map_detail.primary_hash(), "manifest should preserve version hash")
	_assert(manifest.get("info_dat_path", "") == "Info.dat", "manifest should surface selected Info.dat path")
	_assert(manifest.get("song_filename", "") == "SyntheticSong.ogg", "manifest should surface song filename from Info.dat")
	_assert(manifest.get("cover_image_filename", "") == "cover.png", "manifest should surface cover image filename from Info.dat")
	_assert(manifest.get("audio_files", []).size() == 1, "manifest should list audio file candidates")
	_assert(manifest.get("difficulty_files", []).size() == 2, "manifest should list difficulty files")
	_assert(FileAccess.file_exists(str(manifest.get("manifest_path", ""))), "manifest JSON should be persisted next to the archive")
	var manifest_json = _read_json_path(str(manifest.get("manifest_path", "")))
	_assert(int(manifest_json.get("archive_entry_count", 0)) == 5, "persisted manifest should match archive facts")

func _validate_testbed_state_and_scene(parser: BeatSaverResponseParser) -> void:
	var validation_root := ProjectSettings.globalize_path(VALIDATION_UI_ARTIFACT_ROOT)
	_cleanup_directory(validation_root)
	var search_payload := _read_json(FIXTURE_SEARCH_PATH)
	var latest_payload := _read_json(FIXTURE_LATEST_PATH)
	var detail_payload := _read_json(FIXTURE_DETAIL_PATH)
	var package_fetcher := _build_fixture_package_fetcher()
	var fake_facade := FakeBeatSaverFacade.new(parser, search_payload, latest_payload, detail_payload, package_fetcher)
	var state := BeatSaverTestbedState.new(fake_facade, VALIDATION_UI_ARTIFACT_ROOT)

	var latest_result := state.load_latest()
	_assert(latest_result.get("ok", false), "testbed state should load latest results")
	_assert(state.visible_result_count() == 2, "latest mode should expose two visible results")
	_assert(fake_facade.latest_calls == 1, "latest mode should call the facade latest seam")

	var search_result := state.load_search("fitbeat")
	_assert(search_result.get("ok", false), "testbed state should load search results")
	_assert(state.visible_result_count() == 2, "search mode should expose two visible results")
	_assert(fake_facade.search_calls == 1, "search mode should call the facade search seam")

	var first_map = state.visible_results[0]
	state.set_filters(first_map.map_id, "")
	_assert(state.visible_result_count() == 1, "local text filter should narrow visible results")
	state.set_filters("", str(first_map.tags[0]) if first_map.tags.size() > 0 else "")
	_assert(state.visible_result_count() >= 1, "tag filter should preserve matching result")
	state.set_filters("", "")

	var selection_result := state.select_map(first_map.map_id)
	_assert(selection_result.get("ok", false), "select_map should fetch and store BeatSaver detail")
	_assert(state.selected_map != null, "select_map should set a selected map")
	_assert(fake_facade.detail_calls >= 1, "select_map should use the facade detail seam")

	var stage_result := state.stage_selected_version()
	_assert(stage_result.get("ok", false), "state staging should call stage_selected_version_artifact")
	_assert(fake_facade.stage_calls == 1, "state staging should call the facade acquisition seam")
	_assert(state.current_status_text().contains("manifest"), "state status should mention the staged manifest")

	var browser = BROWSER_SCENE.instantiate()
	browser.auto_bootstrap = false
	browser.state = BeatSaverTestbedState.new(fake_facade, VALIDATION_UI_ARTIFACT_ROOT)
	root.add_child(browser)
	await process_frame
	browser.state.load_search("fitbeat")
	await process_frame
	var results_grid = browser.get_node("RootMargin/RootLayout/BodyLayout/ResultsPanel/ResultsMargin/ResultsVBox/ResultsScroll/ResultsGrid")
	_assert(results_grid.get_child_count() == browser.state.visible_result_count(), "browser scene should render one card per visible result")
	if results_grid.get_child_count() > 0:
		var first_card = results_grid.get_child(0)
		first_card.emit_signal("pressed")
		await process_frame
		_assert(browser.state.selected_map != null, "pressing a result card should select a map detail")
		_assert(browser.get_node("RootMargin/RootLayout/BodyLayout/DetailPanel").visible, "selecting a result should reveal the right-side detail panel")
		browser.get_node("RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DownloadButton").emit_signal("pressed")
		await process_frame
		_assert(browser.state.last_download_result.get("ok", false), "download CTA should stage the selected BeatSaver ZIP")
		var manifest_path := str(browser.state.last_download_result.get("data", {}).get("manifest", {}).get("manifest_path", ""))
		_assert(FileAccess.file_exists(manifest_path), "browser CTA should persist a manifest to the local artifacts folder")
	browser.queue_free()
	await process_frame

func _build_fixture_package_fetcher() -> BeatSaverPackageFetcher:
	return BeatSaverPackageFetcher.new(null, func(_download_url: String, destination_path: String, _options: Dictionary) -> Dictionary:
		var bytes := FileAccess.get_file_as_bytes(FIXTURE_PACKAGE_PATH)
		var file := FileAccess.open(destination_path, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": {"category": "test", "message": "failed to open fixture destination", "code": ERR_CANT_CREATE}}
		file.store_buffer(bytes)
		file.flush()
		file.close()
		return {"ok": true, "destination_path": destination_path, "bytes_written": bytes.size()}
	)

func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	_assert(parsed is Dictionary, "fixture should decode as dictionary: %s" % path)
	return parsed

func _read_json_path(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	_assert(parsed is Dictionary, "json path should decode as dictionary: %s" % path)
	return parsed

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var child_path := "%s/%s" % [path.rstrip("/"), entry]
		if dir.current_is_dir():
			_cleanup_directory(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error(message)
