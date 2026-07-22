extends SceneTree

const BeatSaverPackageFetcher = preload("res://addons/aerobeat-vendor-beatsaver/src/acquisition/beatsaver_package_fetcher.gd")
const BeatSaverVendorFacade = preload("res://addons/aerobeat-vendor-beatsaver/src/facade/beatsaver_vendor_facade.gd")
const BeatSaverBrowserTestbed = preload("res://scripts/beatsaver_browser_testbed.gd")
const BeatSaverTestbedState = preload("res://scripts/beatsaver_testbed_state.gd")
const BeatSaverHttpClient = preload("res://addons/aerobeat-vendor-beatsaver/src/client/beatsaver_http_client.gd")
const BeatSaverRequestBuilder = preload("res://addons/aerobeat-vendor-beatsaver/src/client/beatsaver_request_builder.gd")
const BeatSaverResponseParser = preload("res://addons/aerobeat-vendor-beatsaver/src/client/beatsaver_response_parser.gd")
const BeatSaverSearchQuery = preload("res://addons/aerobeat-vendor-beatsaver/src/models/beatsaver_search_query.gd")

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

class FakeContentAuthoringService:
	extends RefCounted

	var convert_calls: int = 0
	var save_calls: int = 0
	var _current_state: Dictionary = {}
	var _last_package_token: String = "beatsaver-fixture"

	func convert_beatsaver_stage_to_current_package(stage_dir: String, _options: Dictionary = {}) -> Dictionary:
		convert_calls += 1
		_last_package_token = stage_dir.get_file()
		_current_state = {
			"songs": [{
				"songId": "ab-song-%s" % _last_package_token,
				"audio": {
					"filePath": "media/audio/%s.wav" % _last_package_token,
					"previewFilePath": "media/audio/%s-preview.wav" % _last_package_token,
					"previewUrl": "https://cdn.example.invalid/%s-preview.wav" % _last_package_token,
					"previewMode": "preview_file",
				}
			}]
		}
		return {"ok": true, "state": _current_state}

	func inspect_beatsaver_stage_source(stage_dir: String, options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "stageDir": stage_dir, "options": options}

	func validate_package_path(package_dir: String, subject: String = "package") -> Dictionary:
		return {"ok": true, "valid": true, "subject": subject, "packageDir": package_dir, "issues": []}

	func save_current_package(destination_dir: String) -> Dictionary:
		save_calls += 1
		DirAccess.make_dir_recursive_absolute(destination_dir)
		var output_dir := destination_dir.path_join("%s-package" % _last_package_token)
		DirAccess.make_dir_recursive_absolute(output_dir.path_join("media/audio"))
		DirAccess.make_dir_recursive_absolute(output_dir.path_join("charts"))
		var package_file := FileAccess.open(output_dir.path_join("song.package.yaml"), FileAccess.WRITE)
		package_file.store_string("schemaId: aerobeat.song-package.v1\nschemaVersion: 1\nrecordVersion: 1\nsongPackageId: ab-songpkg-%s\nsongPackageName: %s Package\npackageVersion: 1.0.0\nsong:\n  schemaId: aerobeat.song.v1\n  schemaVersion: 1\n  recordVersion: 1\n  songId: ab-song-%s\n  songName: %s\n  audio:\n    filePath: media/audio/%s.wav\n    previewFilePath: media/audio/%s-preview.wav\n    previewMode: preview_file\ncharts:\n  - setId: ab-set-%s\n    setName: %s Normal\n    chartId: ab-chart-%s\n    path: charts/ab-chart-%s.yaml\n" % [_last_package_token, _last_package_token.capitalize(), _last_package_token, _last_package_token.capitalize(), _last_package_token, _last_package_token, _last_package_token, _last_package_token.capitalize(), _last_package_token, _last_package_token])
		package_file.close()
		var chart_file := FileAccess.open(output_dir.path_join("charts/ab-chart-%s.yaml" % _last_package_token), FileAccess.WRITE)
		chart_file.store_string("schemaId: aerobeat.chart.boxing.v1\nschemaVersion: 1\nrecordVersion: 1\nchartId: ab-chart-%s\nchartName: %s Normal\nfeature: boxing\ndifficulty: Normal\nbeats:\n  - start: 1.0\n    type: straight_left\n" % [_last_package_token, _last_package_token.capitalize()])
		chart_file.close()
		var audio_file := FileAccess.open(output_dir.path_join("media/audio/%s.wav" % _last_package_token), FileAccess.WRITE)
		audio_file.store_buffer(_build_silent_wav_bytes())
		audio_file.close()
		var preview_file := FileAccess.open(output_dir.path_join("media/audio/%s-preview.wav" % _last_package_token), FileAccess.WRITE)
		preview_file.store_buffer(_build_silent_wav_bytes())
		preview_file.close()
		var zip_file := FileAccess.open("%s.zip" % output_dir, FileAccess.WRITE)
		zip_file.store_string("fake zip")
		zip_file.close()
		return {"ok": true, "outputDir": output_dir, "zipPath": "%s.zip" % output_dir}

	func get_current_package_state() -> Dictionary:
		return _current_state.duplicate(true)

	func _build_silent_wav_bytes(sample_rate: int = 22050, frames: int = 2205) -> PackedByteArray:
		var data_size := frames * 2
		var riff_size := 36 + data_size
		var bytes := PackedByteArray()
		bytes.resize(44 + data_size)
		bytes.encode_u8(0, 0x52)
		bytes.encode_u8(1, 0x49)
		bytes.encode_u8(2, 0x46)
		bytes.encode_u8(3, 0x46)
		bytes.encode_u32(4, riff_size)
		bytes.encode_u8(8, 0x57)
		bytes.encode_u8(9, 0x41)
		bytes.encode_u8(10, 0x56)
		bytes.encode_u8(11, 0x45)
		bytes.encode_u8(12, 0x66)
		bytes.encode_u8(13, 0x6d)
		bytes.encode_u8(14, 0x74)
		bytes.encode_u8(15, 0x20)
		bytes.encode_u32(16, 16)
		bytes.encode_u16(20, 1)
		bytes.encode_u16(22, 1)
		bytes.encode_u32(24, sample_rate)
		bytes.encode_u32(28, sample_rate * 2)
		bytes.encode_u16(32, 2)
		bytes.encode_u16(34, 16)
		bytes.encode_u8(36, 0x64)
		bytes.encode_u8(37, 0x61)
		bytes.encode_u8(38, 0x74)
		bytes.encode_u8(39, 0x61)
		bytes.encode_u32(40, data_size)
		for index in range(data_size):
			bytes[44 + index] = 0
		return bytes

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

func _build_silent_wav_bytes(sample_rate: int = 22050, frames: int = 2205) -> PackedByteArray:
	var data_size := frames * 2
	var riff_size := 36 + data_size
	var bytes := PackedByteArray()
	bytes.resize(44 + data_size)
	bytes.encode_u8(0, 0x52)
	bytes.encode_u8(1, 0x49)
	bytes.encode_u8(2, 0x46)
	bytes.encode_u8(3, 0x46)
	bytes.encode_u32(4, riff_size)
	bytes.encode_u8(8, 0x57)
	bytes.encode_u8(9, 0x41)
	bytes.encode_u8(10, 0x56)
	bytes.encode_u8(11, 0x45)
	bytes.encode_u8(12, 0x66)
	bytes.encode_u8(13, 0x6d)
	bytes.encode_u8(14, 0x74)
	bytes.encode_u8(15, 0x20)
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1)
	bytes.encode_u16(22, 1)
	bytes.encode_u32(24, sample_rate)
	bytes.encode_u32(28, sample_rate * 2)
	bytes.encode_u16(32, 2)
	bytes.encode_u16(34, 16)
	bytes.encode_u8(36, 0x64)
	bytes.encode_u8(37, 0x61)
	bytes.encode_u8(38, 0x74)
	bytes.encode_u8(39, 0x61)
	bytes.encode_u32(40, data_size)
	for index in range(data_size):
		bytes[44 + index] = 0
	return bytes

func _validate_request_builder(builder: BeatSaverRequestBuilder) -> void:
	var search_query := BeatSaverSearchQuery.new("fitbeat", 2, 10, "latest", false)
	var search_request := builder.build_search_request(search_query)
	_assert(search_request.path == "/search/text/2", "search path should target page 2")
	_assert(search_request.query.get("q", "") == "fitbeat", "search query should include text")
	_assert(int(search_request.query.get("pageSize", 0)) == 10, "search pageSize should be preserved")
	_assert(search_request.query.get("order", "") == "Latest", "search order should use the provider's TitleCase enum")
	_assert(not search_request.query.has("sortOrder"), "search request should not use the legacy sortOrder parameter")
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
	_assert(bool(search_result.get("ok", false)), "facade search should succeed")
	_assert(Array(Dictionary(search_result.get("data", {})).get("maps", [])).size() == 2, "facade search should return normalized maps")

	var detail_result := facade.fetch_map_detail_by_id("1")
	_assert(bool(detail_result.get("ok", false)), "facade detail-by-id should succeed")
	_assert(detail_result.get("data", null).map_name == "succducc - me & u", "facade detail-by-id should return normalized detail")

	var hash_result := facade.fetch_map_detail_by_hash("fda568fc27c20d21f8dc6f3709b49b5cc96723be")
	_assert(bool(hash_result.get("ok", false)), "facade detail-by-hash should succeed")
	_assert(hash_result.get("data", null).primary_hash() == "fda568fc27c20d21f8dc6f3709b49b5cc96723be", "facade detail-by-hash should preserve hash")

	var latest_result := facade.list_latest_maps({"page_size": 2})
	_assert(bool(latest_result.get("ok", false)), "facade latest listing should succeed")
	_assert(Array(Dictionary(latest_result.get("data", {})).get("maps", [])).size() == 2, "facade latest listing should return normalized maps")

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
	var staged_data: Dictionary = Dictionary(staged.get("data", {}))
	var stage: Dictionary = Dictionary(staged_data.get("stage", {}))
	var archive: Dictionary = Dictionary(staged_data.get("archive", {}))
	var manifest: Dictionary = Dictionary(staged_data.get("manifest", {}))
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
	var fake_authoring := FakeContentAuthoringService.new()
	var shell_open_targets: Array = []
	var shell_opener := func(target: String) -> int:
		shell_open_targets.append(target)
		return OK
	var state := BeatSaverTestbedState.new(fake_facade, VALIDATION_UI_ARTIFACT_ROOT, fake_authoring, shell_opener)

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
	_assert(state.action_button_text() == "Download", "fresh selection should truthfully start at Download")
	_assert(state.preview_button_text() == "Preview Remote", "fresh selection should expose remote preview truth")
	_assert(String(state.selected_preview_target().get("kind", "")) == "remote_preview_url", "preview should start remote before conversion")

	var workflow_result := await state.run_selected_version_action(root, state.selected_version_identifier)
	_assert(workflow_result.get("ok", false), "state workflow should run download -> stage -> convert -> inspect")
	_assert(fake_facade.stage_calls == 1, "state workflow should call the facade staging seam once")
	_assert(fake_authoring.convert_calls == 1, "state workflow should delegate conversion to content authoring")
	_assert(fake_authoring.save_calls == 1, "state workflow should save the converted package once")
	_assert(state.action_button_text() == "Inspect", "completed workflow should switch CTA to Inspect")
	_assert(not state.action_button_disabled(), "Inspect should re-enable the CTA")
	_assert(state.preview_button_text() == "Preview Local", "completed workflow should prefer local preview truth")
	_assert(String(state.selected_preview_target().get("kind", "")) == "local_preview", "completed workflow should prefer local preview files")
	var package_dir := String(state._selected_package_record().get("package_dir", ""))
	_assert(DirAccess.dir_exists_absolute(package_dir), "converted package directory should exist after workflow")
	_assert(shell_open_targets.size() == 1 and shell_open_targets[0] == package_dir, "workflow should auto-open the converted package for inspection")

	var preview_result := state.preview_selected_version()
	_assert(preview_result.get("ok", false), "preview selection should resolve the selected preview target")
	_assert(shell_open_targets.size() == 1, "preview selection should not shell-open audio playback targets")
	_assert(String(preview_result.get("kind", "")) == "local_preview", "preview selection should preserve local preview truth after conversion")

	_cleanup_directory(package_dir)
	state.select_map(first_map.map_id)
	_assert(state.action_button_text() == "Download", "reselecting after deleting local package should fall back to Download")
	_assert(String(state.selected_preview_target().get("kind", "")) == "remote_preview_url", "preview should fall back to remote when local package is gone")

	var bridge_shell_open_targets: Array = []
	var bridge_state := BeatSaverTestbedState.new(fake_facade, "%s/bridge" % VALIDATION_UI_ARTIFACT_ROOT, null, func(target: String) -> int:
		bridge_shell_open_targets.append(target)
		return OK
	)
	bridge_state.load_search("fitbeat")
	bridge_state.select_map(first_map.map_id)
	var bridge_workflow := await bridge_state.run_selected_version_action(root, bridge_state.selected_version_identifier)
	_assert(bool(bridge_workflow.get("ok", false)), "default bridge should report success when shared content-core validation is runtime-loadable")
	var bridge_preview_kind := String(bridge_state.selected_preview_target().get("kind", ""))
	_assert(bridge_preview_kind == "local_preview" or bridge_preview_kind == "local_source_audio", "default bridge should prefer local converted audio truth after conversion")
	var bridge_package_record := bridge_state._selected_package_record()
	var bridge_validation := Dictionary(bridge_package_record.get("validation", {}))
	var bridge_core_validation := Dictionary(bridge_validation.get("coreValidation", {}))
	_assert(bool(bridge_validation.get("valid", false)), "default bridge package validation should pass when delegated validation is available")
	_assert(String(bridge_validation.get("delegatedValidator", "")) == "aerobeat-content-core", "default bridge should delegate package validation to aerobeat-content-core")
	_assert(String(bridge_core_validation.get("delegatedValidator", "")) == "aerobeat-content-core", "default bridge core validation should preserve shared-validator truth")
	_assert(Array(bridge_validation.get("issues", [])).is_empty(), "default bridge should not surface shared-validator unavailability issues once content-core is mounted")
	_assert(bridge_state.action_button_text() == "Inspect", "default bridge CTA should advance to Inspect after successful package validation")
	var bridge_package_dir := String(bridge_package_record.get("package_dir", ""))
	_assert(_package_charts_have_beats(bridge_package_dir), "default bridge should save package charts with non-empty beats arrays")
	_assert(bridge_shell_open_targets.size() == 1 and bridge_shell_open_targets[0] == bridge_package_dir, "default bridge should auto-open the converted package after successful validation")
	_cleanup_directory(bridge_package_dir)
	bridge_state.select_map(first_map.map_id)
	_assert(bridge_state.action_button_text() == "Download", "default bridge should fall back to Download after deleting the local package")
	_assert(String(bridge_state.selected_preview_target().get("kind", "")) == "remote_preview_url", "default bridge should preserve remote preview truth after deleting the local package")

	var browser: BeatSaverBrowserTestbed = BROWSER_SCENE.instantiate()
	browser.auto_bootstrap = false
	browser.state = BeatSaverTestbedState.new(fake_facade, VALIDATION_UI_ARTIFACT_ROOT, fake_authoring, shell_opener)
	browser.preview_remote_fetcher = func(_url: String) -> Dictionary:
		return {
			"ok": true,
			"headers": PackedStringArray(["content-type: audio/wav"]),
			"body": _build_silent_wav_bytes(),
		}
	root.add_child(browser)
	await process_frame
	browser.size = Vector2(980, 720)
	await process_frame
	browser.state.load_search("fitbeat")
	await process_frame
	var results_grid = browser.get_node("RootMargin/RootLayout/BodyLayout/ResultsPanel/ResultsMargin/ResultsVBox/ResultsScroll/ResultsGrid")
	_assert(results_grid.get_child_count() == browser.state.visible_result_count(), "browser scene should render one card per visible result")
	_assert(results_grid.columns >= 1 and results_grid.columns <= 2, "results grid should use a bounded adaptive column count")
	if results_grid.get_child_count() > 0:
		var first_card: Control = results_grid.get_child(0)
		_assert(first_card.custom_minimum_size.x >= 280.0, "result cards should advertise a usable minimum width")
		_assert(first_card.size.x >= 260.0, "result cards should render wider than a collapsed sliver")
		first_card.emit_signal("pressed")
		await process_frame
		_assert(browser.state.selected_map != null, "pressing a result card should select a map detail")
		_assert(browser.get_node("RootMargin/RootLayout/BodyLayout/DetailPanel").visible, "selecting a result should reveal the right-side detail panel")
		await process_frame
		var selected_card: Control = results_grid.get_child(0)
		_assert(selected_card.size.x >= 260.0, "result cards should remain readable after the detail panel opens")
		var preview_button: Button = browser.get_node("RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/PreviewButton")
		var download_button: Button = browser.get_node("RootMargin/RootLayout/BodyLayout/DetailPanel/DetailMargin/DetailVBox/DownloadButton")
		var preview_player: AudioStreamPlayer = browser.get_node("PreviewAudioPlayer")
		_assert(preview_button.text == "Preview Remote", "detail panel should show remote preview before acquisition")
		_assert(download_button.text == "Download", "detail panel should start with Download before acquisition")
		var remote_preview_result := await browser.play_selected_preview()
		_assert(remote_preview_result.get("ok", false), "browser preview should fetch and play remote audio in-engine before acquisition")
		_assert(String(remote_preview_result.get("kind", "")) == "remote_preview_url", "browser preview should preserve remote preview truth before acquisition")
		_assert(FileAccess.file_exists(browser.last_preview_cache_path), "browser preview should cache remote preview audio under user://")
		_assert(preview_player.stream != null, "browser preview should load an audio stream for remote playback")
		download_button.emit_signal("pressed")
		for _i in range(12):
			await process_frame
			if browser.state.action_button_text() == "Inspect":
				break
		_assert(browser.state.last_download_result.get("ok", false), "download CTA should stage the selected BeatSaver ZIP")
		var manifest_path := str(browser.state.last_download_result.get("data", {}).get("manifest", {}).get("manifest_path", ""))
		_assert(FileAccess.file_exists(manifest_path), "browser CTA should persist a manifest to the local artifacts folder")
		_assert(download_button.text == "Inspect", "detail panel CTA should promote to Inspect after conversion")
		_assert(preview_button.text == "Preview Local", "detail panel preview should prefer local media after conversion")
		var local_preview_result := await browser.play_selected_preview()
		_assert(local_preview_result.get("ok", false), "browser preview should play local converted audio in-engine after conversion")
		_assert(String(local_preview_result.get("kind", "")) == "local_preview", "browser preview should prefer the local preview file after conversion")
		_assert(preview_player.stream != null, "browser preview should keep a playable local stream after conversion")
	browser.queue_free()
	await process_frame

func _build_fixture_package_fetcher() -> BeatSaverPackageFetcher:
	return BeatSaverPackageFetcher.new(null, func(_download_url: String, destination_path: String, options: Dictionary) -> Dictionary:
		var progress_callback: Callable = options.get("progress_callback", Callable())
		if progress_callback.is_valid():
			progress_callback.call({"bytesDownloaded": 0, "contentLength": 100, "progress": 0.0})
		var bytes := FileAccess.get_file_as_bytes(FIXTURE_PACKAGE_PATH)
		var file := FileAccess.open(destination_path, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": {"category": "test", "message": "failed to open fixture destination", "code": ERR_CANT_CREATE}}
		file.store_buffer(bytes)
		file.flush()
		file.close()
		if progress_callback.is_valid():
			progress_callback.call({"bytesDownloaded": bytes.size(), "contentLength": bytes.size(), "progress": 1.0})
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

func _package_charts_have_beats(package_dir: String) -> bool:
	if package_dir.is_empty():
		return false
	var charts_dir := package_dir.path_join("charts")
	if not DirAccess.dir_exists_absolute(charts_dir):
		return false
	var chart_paths: PackedStringArray = DirAccess.get_files_at(charts_dir)
	if chart_paths.is_empty():
		return false
	for chart_name in chart_paths:
		if not chart_name.ends_with(".yaml") and not chart_name.ends_with(".yml"):
			continue
		var chart_text := FileAccess.get_file_as_string(charts_dir.path_join(chart_name))
		if not chart_text.contains("beats:\n  - "):
			return false
	return true

func _has_issue_code(issues: Array, code: String) -> bool:
	for issue in issues:
		if String(Dictionary(issue).get("code", "")) == code:
			return true
	return false

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error(message)
