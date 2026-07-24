class_name BeatSaverTestbedState
extends RefCounted

class ContentAuthoringBridge:
	extends RefCounted

	const CONVERSION_SERVICE_PATH := "res://addons/aerobeat-tool-content-authoring/src/services/importers/beatsaver_stage_conversion_service.gd"
	const WORKFLOW_SERVICE_PATH := "res://addons/aerobeat-tool-content-authoring/src/services/workflow/song_package_workflow_service.gd"

	var _conversion_service = null
	var _workflow_service = null
	var _current_state: Dictionary = {}

	func _init() -> void:
		var conversion_script = load(CONVERSION_SERVICE_PATH)
		var workflow_script = load(WORKFLOW_SERVICE_PATH)
		_conversion_service = conversion_script.new() if conversion_script != null else null
		_workflow_service = workflow_script.new() if workflow_script != null else null

	func inspect_beatsaver_stage_source(stage_dir: String, options: Dictionary = {}) -> Dictionary:
		if _conversion_service == null:
			return {"ok": false, "error": {"message": "BeatSaver conversion service could not be loaded from aerobeat-tool-content-authoring."}}
		if _conversion_service.has_method("inspect_stage"):
			return _conversion_service.inspect_stage(stage_dir, options)
		return {"ok": false, "error": {"message": "BeatSaver stage inspection is unavailable."}}

	func convert_beatsaver_stage_to_current_package(stage_dir: String, options: Dictionary = {}) -> Dictionary:
		if _conversion_service == null:
			return {"ok": false, "error": {"message": "BeatSaver conversion service could not be loaded from aerobeat-tool-content-authoring."}}
		var result: Dictionary = _conversion_service.convert_stage(stage_dir, options)
		if bool(result.get("ok", false)):
			_current_state = Dictionary(result.get("state", {})).duplicate(true)
			result["state"] = get_current_package_state()
		return result

	func validate_package_path(package_dir: String, subject: String = "package") -> Dictionary:
		var validation_service_path := "res://addons/aerobeat-tool-content-authoring/src/services/validation/song_package_validation_service.gd"
		var validation_script = load(validation_service_path)
		if validation_script == null:
			return {"ok": false, "valid": false, "issues": [{"code": "validation_service_unavailable", "message": "BeatSaver validation bridge could not load the shared package validator."}]}
		var service = validation_script.new()
		var report: Dictionary = service.validate_path(package_dir, subject)
		report["ok"] = bool(report.get("valid", false))
		return report

	func save_current_package(destination_dir: String) -> Dictionary:
		if _workflow_service == null:
			return {"ok": false, "error": {"message": "BeatSaver package workflow service could not be loaded from aerobeat-tool-content-authoring."}}
		if _current_state.is_empty():
			return {"ok": false, "error": {"message": "No converted package state is available to save."}}
		DirAccess.make_dir_recursive_absolute(destination_dir)
		var package_name: String = _package_folder_name(_current_state)
		var staging_dir: String = ProjectSettings.globalize_path("user://beatsaver_testbed_bridge/staging/%s" % package_name)
		_remove_tree(staging_dir)
		DirAccess.make_dir_recursive_absolute(staging_dir)
		var write_result: Dictionary = _workflow_service.write_package_state(get_current_package_state(), staging_dir)
		if not bool(write_result.get("ok", false)):
			return write_result
		var output_dir: String = destination_dir.path_join(package_name)
		_remove_tree(output_dir)
		DirAccess.make_dir_recursive_absolute(output_dir)
		var copied_files: Array = []
		_copy_tree(staging_dir, output_dir, copied_files)
		if DirAccess.dir_exists_absolute(staging_dir.path_join(".artifacts")):
			DirAccess.make_dir_recursive_absolute(output_dir.path_join(".artifacts"))
			_copy_tree(staging_dir, output_dir, copied_files, ".artifacts")
		var zip_path: String = "%s.zip" % output_dir
		var zip_result: Dictionary = _zip_directory(output_dir, zip_path)
		return {
			"ok": bool(zip_result.get("ok", false)),
			"outputDir": output_dir,
			"zipPath": zip_path,
			"copiedFiles": copied_files,
			"zipResult": zip_result,
		}

	func get_current_package_state() -> Dictionary:
		return _current_state.duplicate(true)

	func _package_folder_name(state: Dictionary) -> String:
		var song_package: Dictionary = Dictionary(state.get("songPackage", {})).duplicate(true)
		var package_id := String(song_package.get("songPackageId", "beatsaver-import-package")).strip_edges()
		if package_id.is_empty():
			return "beatsaver-import-package"
		return package_id.replace("/", "-").replace(" ", "-")

	func _copy_tree(source_dir: String, output_dir: String, copied_files: Array, relative_path: String = "") -> void:
		var current_source: String = source_dir if relative_path.is_empty() else source_dir.path_join(relative_path)
		var dir := DirAccess.open(current_source)
		if dir == null:
			return
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name.is_empty():
				break
			if _should_skip_name(name):
				continue
			var child_relative: String = name if relative_path.is_empty() else relative_path.path_join(name)
			if dir.current_is_dir():
				if name == "cache":
					continue
				DirAccess.make_dir_recursive_absolute(output_dir.path_join(child_relative))
				_copy_tree(source_dir, output_dir, copied_files, child_relative)
			else:
				var source_path: String = source_dir.path_join(child_relative)
				var destination_path: String = output_dir.path_join(child_relative)
				DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
				if DirAccess.copy_absolute(source_path, destination_path) == OK:
					copied_files.append(child_relative)
		dir.list_dir_end()

	func _zip_directory(source_dir: String, zip_path: String) -> Dictionary:
		DirAccess.remove_absolute(zip_path)
		var zipper := ZIPPacker.new()
		var open_error := zipper.open(zip_path)
		if open_error != OK:
			return {"ok": false, "errorCode": "zip_open_failed", "error": open_error}
		var files: Array = []
		var zip_error: int = _zip_directory_recursive(zipper, source_dir, source_dir, files)
		if zip_error == OK and DirAccess.dir_exists_absolute(source_dir.path_join(".artifacts")):
			zip_error = _zip_directory_recursive(zipper, source_dir, source_dir.path_join(".artifacts"), files)
		zipper.close()
		return {
			"ok": zip_error == OK,
			"errorCode": "" if zip_error == OK else "zip_write_failed",
			"error": zip_error,
			"files": files,
		}

	func _zip_directory_recursive(zipper: ZIPPacker, root_dir: String, current_dir: String, files: Array) -> int:
		var dir := DirAccess.open(current_dir)
		if dir == null:
			return ERR_CANT_OPEN
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name.is_empty():
				break
			if _should_skip_name(name):
				continue
			var absolute_path: String = current_dir.path_join(name)
			if dir.current_is_dir():
				var nested_error: int = _zip_directory_recursive(zipper, root_dir, absolute_path, files)
				if nested_error != OK:
					return nested_error
				continue
			var relative_path: String = absolute_path.trim_prefix(root_dir.path_join(""))
			var start_error := zipper.start_file(relative_path)
			if start_error != OK:
				return start_error
			zipper.write_file(FileAccess.get_file_as_bytes(absolute_path))
			zipper.close_file()
			files.append(relative_path)
		dir.list_dir_end()
		return OK

	func _should_skip_name(name: String) -> bool:
		if name == "." or name == "..":
			return true
		if not name.begins_with("."):
			return false
		return name != ".artifacts"

	func _remove_tree(path: String) -> void:
		if not DirAccess.dir_exists_absolute(path):
			return
		var dir := DirAccess.open(path)
		if dir == null:
			return
		dir.list_dir_begin()
		while true:
			var name := dir.get_next()
			if name.is_empty():
				break
			if name == "." or name == "..":
				continue
			var child_path := path.path_join(name)
			if dir.current_is_dir():
				_remove_tree(child_path)
				DirAccess.remove_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		dir.list_dir_end()
		DirAccess.remove_absolute(path)

signal state_changed

const ACTION_DOWNLOAD := "download"
const ACTION_STAGING := "staging"
const ACTION_CONVERTING := "converting"
const ACTION_INSPECT := "inspect"
const ACTION_VALIDATION_FAILED := "validation_failed"

var facade
var content_authoring
var artifact_root: String
var mode: String = "latest"
var remote_query_text: String = ""
var selected_tag_filters: PackedStringArray = PackedStringArray()
var page_size: int = 12
var include_automapper = null
var latest_sort: String = "latest"
var search_sort_order: String = "relevance"
var selected_difficulty_filters: PackedStringArray = PackedStringArray()
var current_page: int = 0
var total_pages: int = 0
var all_results: Array = []
var visible_results: Array = []
var selected_map = null
var selected_map_id: String = ""
var selected_version_identifier: String = ""
var last_collection_response: Dictionary = {}
var last_download_result: Dictionary = {}
var last_conversion_result: Dictionary = {}
var last_preview_result: Dictionary = {}
var last_inspect_result: Dictionary = {}
var error_message: String = ""
var busy: bool = false
var package_records := {}
var shell_opener: Callable
var async_catalog_loading_enabled: bool = true
var _collection_request_serial: int = 0
var _active_collection_request_serial: int = 0
var _detail_request_serial: int = 0
var _active_detail_request_serial: int = 0
var _pending_search_page: int = -1
var _blocked_search_page: int = -1

func _init(p_facade = null, p_artifact_root: String = "res://.artifacts", p_content_authoring = null, p_shell_opener: Callable = Callable(), p_async_catalog_loading_enabled: bool = true) -> void:
	facade = p_facade if p_facade != null else BeatSaverVendorFacade.new()
	artifact_root = p_artifact_root
	content_authoring = p_content_authoring if p_content_authoring != null else ContentAuthoringBridge.new()
	shell_opener = p_shell_opener
	async_catalog_loading_enabled = p_async_catalog_loading_enabled

func load_search(query_text: String = "", page: int = 0, append: bool = false) -> Dictionary:
	mode = "search"
	remote_query_text = query_text.strip_edges() if not query_text.is_empty() else remote_query_text
	if append:
		if _pending_search_page == page:
			return {"ok": false, "error": {"message": "BeatSaver page %d is already loading." % page}}
		if _blocked_search_page == page:
			return {"ok": false, "error": {"message": "BeatSaver page %d previously failed to load. Refresh or change the search to retry it." % page}}
	else:
		_blocked_search_page = -1
		_pending_search_page = -1
	busy = true
	error_message = ""
	var query := BeatSaverSearchQuery.new(remote_query_text, page, page_size, search_sort_order, include_automapper, PackedStringArray(), "")
	if _can_use_async_catalog_facade() and facade.has_method("search_maps_async"):
		_collection_request_serial += 1
		var request_serial := _collection_request_serial
		_active_collection_request_serial = request_serial
		_pending_search_page = page if append else -1
		emit_signal("state_changed")
		var accepted: Dictionary = facade.search_maps_async(query, func(response: Dictionary) -> void:
			_finalize_search_load(request_serial, page, append, response)
		)
		if not bool(accepted.get("ok", false)):
			busy = false
			_pending_search_page = -1
			error_message = str(Dictionary(accepted.get("error", {})).get("message", "BeatSaver request failed to start."))
			emit_signal("state_changed")
		return accepted
	var response: Dictionary = facade.search_maps(query)
	busy = false
	_pending_search_page = -1
	if not bool(response.get("ok", false)) and append:
		_blocked_search_page = page
	else:
		_blocked_search_page = -1
	return _consume_collection_response(response, append, page)

func load_latest() -> Dictionary:
	mode = "latest"
	_blocked_search_page = -1
	_pending_search_page = -1
	busy = true
	error_message = ""
	var request_options := {
		"page_size": page_size,
		"sort": latest_sort,
		"automapper": include_automapper
	}
	if _can_use_async_catalog_facade() and facade.has_method("list_latest_maps_async"):
		_collection_request_serial += 1
		var request_serial := _collection_request_serial
		_active_collection_request_serial = request_serial
		emit_signal("state_changed")
		var accepted: Dictionary = facade.list_latest_maps_async(func(response: Dictionary) -> void:
			_finalize_latest_load(request_serial, response)
		, request_options)
		if not bool(accepted.get("ok", false)):
			busy = false
			error_message = str(Dictionary(accepted.get("error", {})).get("message", "BeatSaver request failed to start."))
			emit_signal("state_changed")
		return accepted
	var response: Dictionary = facade.list_latest_maps(request_options)
	busy = false
	return _consume_collection_response(response, false)

func refresh_active_mode() -> Dictionary:
	if mode == "search":
		return load_search(remote_query_text, 0, false)
	return load_latest()

func load_next_page() -> Dictionary:
	var next_page := current_page + 1
	if _blocked_search_page == next_page:
		return {
			"ok": false,
			"error": {"message": "BeatSaver page %d previously failed to load. Refresh or change the search to retry it." % next_page}
		}
	if not can_load_more_search_results():
		return {
			"ok": false,
			"error": {"message": "No additional BeatSaver search results are available."}
		}
	return load_search(remote_query_text, next_page, true)

func can_load_more_search_results() -> bool:
	if mode != "search" or busy:
		return false
	var next_page := current_page + 1
	if _blocked_search_page == next_page or _pending_search_page == next_page:
		return false
	return next_page < total_pages

func _resolve_search_total_pages(data: Dictionary) -> int:
	var provider_pages := maxi(0, int(data.get("pages", 0)))
	var provider_total := maxi(0, int(data.get("total", 0)))
	var inferred_pages := 0
	if provider_total > 0:
		inferred_pages = int(ceili(float(provider_total) / float(maxi(1, page_size))))
	var resolved_pages := maxi(provider_pages, inferred_pages)
	resolved_pages = maxi(resolved_pages, current_page + 1)
	return resolved_pages

func set_filters(tag_filters: PackedStringArray = PackedStringArray(), difficulty_filters: PackedStringArray = PackedStringArray()) -> void:
	selected_tag_filters = _sanitize_tag_filters(tag_filters)
	selected_difficulty_filters = _sanitize_difficulty_filters(difficulty_filters)
	_rebuild_visible_results()
	emit_signal("state_changed")

func selected_genre_tags() -> PackedStringArray:
	return selected_tag_filters.duplicate()

func selected_difficulties() -> PackedStringArray:
	return selected_difficulty_filters.duplicate()

func available_genre_tags() -> PackedStringArray:
	var seen := {}
	var options := PackedStringArray()
	for map_detail in all_results:
		if map_detail == null:
			continue
		for raw_tag in map_detail.tags:
			var normalized_tag := str(raw_tag).strip_edges()
			if normalized_tag.is_empty() or seen.has(normalized_tag):
				continue
			seen[normalized_tag] = true
			options.append(normalized_tag)
	options.sort()
	return options

func available_difficulties() -> PackedStringArray:
	var order := PackedStringArray(["Easy", "Normal", "Hard", "Expert", "ExpertPlus"])
	var available := {}
	for map_detail in all_results:
		if map_detail == null:
			continue
		for version_ref in map_detail.versions:
			for difficulty_ref in version_ref.difficulties:
				var normalized := _normalize_difficulty_name(String(difficulty_ref.difficulty))
				if not normalized.is_empty():
					available[normalized] = true
	for difficulty_name in selected_difficulty_filters:
		if not difficulty_name.is_empty():
			available[difficulty_name] = true
	var options := PackedStringArray()
	for difficulty_name in order:
		if available.is_empty() or available.has(difficulty_name):
			options.append(difficulty_name)
	return options

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
	if _can_use_async_catalog_facade() and facade.has_method("fetch_map_detail_by_id_async"):
		_detail_request_serial += 1
		var request_serial := _detail_request_serial
		_active_detail_request_serial = request_serial
		var accepted: Dictionary = facade.fetch_map_detail_by_id_async(normalized_id, func(response: Dictionary) -> void:
			_finalize_select_map(request_serial, normalized_id, response)
		)
		if not bool(accepted.get("ok", false)):
			busy = false
			error_message = str(Dictionary(accepted.get("error", {})).get("message", "Failed to load BeatSaver map detail."))
			emit_signal("state_changed")
		return accepted
	var response: Dictionary = facade.fetch_map_detail_by_id(normalized_id)
	busy = false
	return _consume_select_map_response(normalized_id, response)

func _can_use_async_catalog_facade() -> bool:
	return async_catalog_loading_enabled

func _finalize_search_load(request_serial: int, page: int, append: bool, response: Dictionary) -> void:
	if request_serial != _active_collection_request_serial:
		return
	busy = false
	_pending_search_page = -1
	if not bool(response.get("ok", false)) and append:
		_blocked_search_page = page
	else:
		_blocked_search_page = -1
	_consume_collection_response(response, append, page)

func _finalize_latest_load(request_serial: int, response: Dictionary) -> void:
	if request_serial != _active_collection_request_serial:
		return
	busy = false
	_pending_search_page = -1
	_blocked_search_page = -1
	_consume_collection_response(response, false)

func _finalize_select_map(request_serial: int, normalized_id: String, response: Dictionary) -> void:
	if request_serial != _active_detail_request_serial:
		return
	busy = false
	_consume_select_map_response(normalized_id, response)

func _consume_select_map_response(normalized_id: String, response: Dictionary) -> Dictionary:
	if not bool(response.get("ok", false)):
		error_message = str(response.get("error", {}).get("message", "Failed to load BeatSaver map detail."))
		emit_signal("state_changed")
		return response
	selected_map = response.get("data", null)
	selected_map_id = normalized_id
	selected_version_identifier = selected_map.primary_hash() if selected_map != null else ""
	error_message = ""
	_refresh_selected_package_truth()
	emit_signal("state_changed")
	return response

func run_selected_version_action(ui_host: Node, version_identifier: String = "") -> Dictionary:
	if selected_map == null:
		var no_selection := {
			"ok": false,
			"error": {"message": "Select a BeatSaver result before starting the package workflow."}
		}
		error_message = str(Dictionary(no_selection.get("error", {})).get("message", "Select a BeatSaver result before starting the package workflow."))
		emit_signal("state_changed")
		return no_selection
	var effective_identifier := _effective_version_identifier(version_identifier)
	selected_version_identifier = effective_identifier
	_refresh_selected_package_truth()
	var selected_package_record: Dictionary = _selected_package_record()
	if _record_has_inspectable_package(selected_package_record):
		last_inspect_result = inspect_selected_version_package()
		return last_inspect_result
	busy = true
	error_message = ""
	last_download_result = {}
	last_conversion_result = {}
	_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_DOWNLOAD, 0, selected_package_record))
	emit_signal("state_changed")
	if ui_host != null and ui_host.get_tree() != null:
		await ui_host.get_tree().process_frame
	var stage_result: Dictionary = facade.stage_selected_version_artifact(selected_map, effective_identifier, artifact_root, {
		"lifecycle_callback": Callable(self, "_on_stage_lifecycle_event").bind(_selected_package_key()),
		"progress_callback": Callable(self, "_on_stage_download_progress").bind(_selected_package_key())
	})
	last_download_result = stage_result
	if not stage_result.get("ok", false):
		busy = false
		error_message = str(stage_result.get("error", {}).get("message", "Failed to stage the selected BeatSaver artifact."))
		_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_DOWNLOAD, 0, _selected_package_record()))
		emit_signal("state_changed")
		return stage_result
	var stage_data: Dictionary = Dictionary(stage_result.get("data", {}).get("stage", {})).duplicate(true)
	var manifest_data: Dictionary = Dictionary(stage_result.get("data", {}).get("manifest", {})).duplicate(true)
	_set_package_record(_selected_package_key(), _merge_record(_selected_package_record(), {
		"action": ACTION_STAGING,
		"progress_percent": 100,
		"stage_directory_path": String(stage_data.get("stage_directory_path", "")),
		"archive_path": String(stage_data.get("archive_path", "")),
		"manifest_path": String(manifest_data.get("manifest_path", "")),
		"remote_preview_url": _selected_remote_preview_url(),
	}))
	emit_signal("state_changed")
	if ui_host != null and ui_host.get_tree() != null:
		await ui_host.get_tree().process_frame
	var stage_dir := String(stage_data.get("stage_directory_path", ""))
	var stage_inspect_result: Dictionary = content_authoring.inspect_beatsaver_stage_source(stage_dir)
	if not bool(stage_inspect_result.get("ok", false)):
		busy = false
		error_message = _extract_conversion_error(stage_inspect_result, "Failed to inspect the staged BeatSaver package.")
		_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_DOWNLOAD, 0, _selected_package_record()))
		emit_signal("state_changed")
		return stage_inspect_result
	_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_CONVERTING, 100, _selected_package_record()))
	emit_signal("state_changed")
	if ui_host != null and ui_host.get_tree() != null:
		await ui_host.get_tree().process_frame
	last_conversion_result = content_authoring.convert_beatsaver_stage_to_current_package(stage_dir)
	last_conversion_result["inspectStage"] = stage_inspect_result
	if not last_conversion_result.get("ok", false):
		busy = false
		error_message = _extract_conversion_error(last_conversion_result, "Failed to convert the staged BeatSaver package.")
		_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_DOWNLOAD, 0, _selected_package_record()))
		emit_signal("state_changed")
		return last_conversion_result
	var save_result: Dictionary = content_authoring.save_current_package(_package_output_root())
	last_conversion_result["save"] = save_result
	if not save_result.get("ok", false):
		busy = false
		error_message = _extract_conversion_error(save_result, "Failed to save the converted AeroBeat package.")
		_set_package_record(_selected_package_key(), _build_record_state(effective_identifier, ACTION_DOWNLOAD, 0, _selected_package_record()))
		emit_signal("state_changed")
		return save_result
	var package_dir := String(save_result.get("outputDir", "")).strip_edges()
	var package_validation: Dictionary = content_authoring.validate_package_path(package_dir, "package")
	save_result["validation"] = package_validation
	var authored_audio := _extract_local_audio_truth(content_authoring.get_current_package_state(), package_dir)
	var validation_ok: bool = _validation_allows_inspect(package_validation)
	_set_package_record(_selected_package_key(), _merge_record(_selected_package_record(), {
		"action": ACTION_INSPECT if validation_ok else ACTION_VALIDATION_FAILED,
		"progress_percent": 100,
		"package_dir": package_dir,
		"package_zip_path": String(save_result.get("zipPath", "")).strip_edges(),
		"local_preview_path": String(authored_audio.get("local_preview_path", "")).strip_edges(),
		"local_source_audio_path": String(authored_audio.get("local_source_audio_path", "")).strip_edges(),
		"remote_preview_url": String(authored_audio.get("remote_preview_url", _selected_remote_preview_url())).strip_edges(),
		"song_audio": Dictionary(authored_audio.get("song_audio", {})).duplicate(true),
		"validation": package_validation,
	}))
	busy = false
	error_message = "" if validation_ok else _validation_failure_message(package_validation)
	emit_signal("state_changed")
	if validation_ok:
		last_inspect_result = inspect_selected_version_package()
	else:
		last_inspect_result = {
			"ok": false,
			"package_dir": package_dir,
			"validation": package_validation,
			"error": {"message": error_message},
		}
	return {
		"ok": validation_ok and bool(last_inspect_result.get("ok", false)),
		"stage": stage_result,
		"convert": last_conversion_result,
		"inspect": last_inspect_result,
		"package": _selected_package_record(),
	}

func preview_selected_version() -> Dictionary:
	var preview_target: Dictionary = selected_preview_target()
	last_preview_result = preview_target.duplicate(true)
	if not bool(preview_target.get("ok", false)):
		error_message = str(preview_target.get("error", {}).get("message", "No preview target is available."))
		emit_signal("state_changed")
		return last_preview_result
	error_message = ""
	emit_signal("state_changed")
	return last_preview_result

func inspect_selected_version_package() -> Dictionary:
	var selected_package_record: Dictionary = _selected_package_record()
	if not _record_has_local_package(selected_package_record):
		var missing := {
			"ok": false,
			"error": {"message": "The converted package is not present on disk yet."}
		}
		last_inspect_result = missing
		error_message = str(Dictionary(missing.get("error", {})).get("message", "The converted package is not present on disk yet."))
		_refresh_selected_package_truth()
		emit_signal("state_changed")
		return missing
	var package_dir := String(selected_package_record.get("package_dir", "")).strip_edges()
	var open_result := _open_external(package_dir)
	last_inspect_result = {
		"ok": open_result == OK,
		"package_dir": package_dir,
		"error": {} if open_result == OK else {"message": "Failed to open the converted package directory.", "code": open_result}
	}
	if open_result != OK:
		error_message = str(last_inspect_result.get("error", {}).get("message", "Failed to open the converted package directory."))
	else:
		error_message = ""
		emit_signal("state_changed")
	return last_inspect_result

func selected_preview_target() -> Dictionary:
	if selected_map == null:
		return {"ok": false, "error": {"message": "Select a BeatSaver result before previewing."}}
	var selected_package_record: Dictionary = _selected_package_record()
	if _record_has_local_package(selected_package_record):
		var local_preview_path := String(selected_package_record.get("local_preview_path", "")).strip_edges()
		if not local_preview_path.is_empty() and FileAccess.file_exists(local_preview_path):
			return {"ok": true, "kind": "local_preview", "target": local_preview_path}
		var local_source_audio_path := String(selected_package_record.get("local_source_audio_path", "")).strip_edges()
		if not local_source_audio_path.is_empty() and FileAccess.file_exists(local_source_audio_path):
			return {"ok": true, "kind": "local_source_audio", "target": local_source_audio_path}
	var remote_preview_url := String(selected_package_record.get("remote_preview_url", _selected_remote_preview_url())).strip_edges()
	if not remote_preview_url.is_empty():
		return {"ok": true, "kind": "remote_preview_url", "target": remote_preview_url}
	return {"ok": false, "error": {"message": "No preview target is available for the selected BeatSaver version."}}

func preview_button_text() -> String:
	var target: Dictionary = selected_preview_target()
	if not bool(target.get("ok", false)):
		return "Preview"
	var kind := String(target.get("kind", ""))
	if kind.begins_with("local_"):
		return "Preview Local"
	return "Preview Remote"

func action_button_text() -> String:
	if selected_map == null:
		return "Download"
	var selected_package_record: Dictionary = _selected_package_record()
	match String(selected_package_record.get("action", ACTION_DOWNLOAD)):
		ACTION_INSPECT:
			return "Inspect"
		ACTION_VALIDATION_FAILED:
			return "Validation Failed"
		ACTION_STAGING:
			return "Staging"
		ACTION_CONVERTING:
			return "Converting"
		_:
			var progress := int(selected_package_record.get("progress_percent", 0))
			if progress > 0 or bool(selected_package_record.get("download_started", false)):
				return "%d%%" % clampi(progress, 0, 100)
			return "Download"

func action_button_disabled() -> bool:
	if selected_map == null:
		return true
	var text := action_button_text()
	return text != "Download" and text != "Inspect"

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
		diff_labels.sort()
		var display_key: String = version_ref.key if not version_ref.key.is_empty() else version_ref.hash.substr(0, min(version_ref.hash.length(), 8))
		var hash_short: String = version_ref.hash.substr(0, min(version_ref.hash.length(), 8))
		var difficulty_summary: String = ", ".join(diff_labels)
		var label: String = "%s • %s" % [display_key, hash_short]
		if not difficulty_summary.is_empty():
			label += " • %s" % difficulty_summary
		options.append({
			"id": version_ref.hash,
			"key": version_ref.key,
			"label": label,
			"download_url": version_ref.download_url,
			"cover_url": version_ref.cover_url,
			"preview_url": version_ref.preview_url,
			"difficulties": diff_labels
		})
	return options

func current_status_text() -> String:
	if busy and error_message.is_empty():
		return "Running BeatSaver testbed package workflow…"
	if not error_message.is_empty():
		return error_message
	var selected_package_record: Dictionary = _selected_package_record()
	if _record_has_local_package(selected_package_record):
		return "Converted package ready at %s" % String(selected_package_record.get("package_dir", ""))
	if last_download_result.get("ok", false):
		var manifest_path := str(last_download_result.get("data", {}).get("manifest", {}).get("manifest_path", ""))
		if not manifest_path.is_empty():
			return "Staged archive + manifest at %s" % manifest_path
		return "Staged BeatSaver artifact."
	if last_collection_response.get("ok", false):
		return "%d result%s ready." % [visible_results.size(), "s" if visible_results.size() != 1 else ""]
	return "Ready."

func _consume_collection_response(response: Dictionary, append: bool = false, requested_page: int = 0) -> Dictionary:
	last_collection_response = response
	if not response.get("ok", false):
		if not append:
			all_results.clear()
			visible_results.clear()
			selected_map = null
			selected_map_id = ""
			selected_version_identifier = ""
		error_message = str(response.get("error", {}).get("message", "BeatSaver request failed."))
		emit_signal("state_changed")
		return response
	var data := Dictionary(response.get("data", {}))
	var incoming_results: Array = Array(data.get("maps", []))
	error_message = ""
	if mode == "search":
		current_page = maxi(0, requested_page)
		total_pages = _resolve_search_total_pages(data)
	else:
		current_page = int(data.get("page", 0))
		total_pages = int(data.get("pages", 0))
	if append:
		for map_detail in incoming_results:
			_append_unique_result(map_detail)
	else:
		all_results = incoming_results
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
	_refresh_selected_package_truth()
	emit_signal("state_changed")
	return response

func _append_unique_result(map_detail) -> void:
	if map_detail == null:
		return
	for existing_map_detail in all_results:
		if existing_map_detail != null and String(existing_map_detail.map_id) == String(map_detail.map_id):
			return
	all_results.append(map_detail)

func _rebuild_visible_results() -> void:
	visible_results.clear()
	for map_detail in all_results:
		if _matches_filters(map_detail):
			visible_results.append(map_detail)

func _matches_filters(map_detail) -> bool:
	if map_detail == null:
		return false
	if not selected_tag_filters.is_empty() and not _map_has_any_tag(map_detail, selected_tag_filters):
		return false
	if not selected_difficulty_filters.is_empty() and not _map_has_any_difficulty(map_detail, selected_difficulty_filters):
		return false
	return true

func _map_has_any_tag(map_detail, required_tags: PackedStringArray) -> bool:
	var map_tags := {}
	for raw_tag in map_detail.tags:
		var normalized_tag := str(raw_tag).strip_edges()
		if not normalized_tag.is_empty():
			map_tags[normalized_tag.to_lower()] = true
	for required_tag in required_tags:
		if map_tags.has(String(required_tag).to_lower()):
			return true
	return false

func _map_has_any_difficulty(map_detail, normalized_difficulties: PackedStringArray) -> bool:
	var wanted := {}
	for difficulty_name in normalized_difficulties:
		wanted[String(difficulty_name)] = true
	for version_ref in map_detail.versions:
		for difficulty_ref in version_ref.difficulties:
			if wanted.has(_normalize_difficulty_name(String(difficulty_ref.difficulty))):
				return true
	return false

func _sanitize_tag_filters(raw_tags: PackedStringArray) -> PackedStringArray:
	var normalized := PackedStringArray()
	var seen := {}
	for raw_tag in raw_tags:
		var tag_text := str(raw_tag).strip_edges()
		if tag_text.is_empty():
			continue
		var seen_key := tag_text.to_lower()
		if seen.has(seen_key):
			continue
		seen[seen_key] = true
		normalized.append(tag_text)
	return normalized

func _sanitize_difficulty_filters(raw_difficulties: PackedStringArray) -> PackedStringArray:
	var normalized := PackedStringArray()
	var seen := {}
	for raw_difficulty in raw_difficulties:
		var difficulty_name := _normalize_difficulty_name(str(raw_difficulty))
		if difficulty_name.is_empty():
			continue
		if seen.has(difficulty_name):
			continue
		seen[difficulty_name] = true
		normalized.append(difficulty_name)
	return normalized

func _normalize_difficulty_name(raw_difficulty: String) -> String:
	return BeatSaverSearchQuery.new("", 0, page_size, "", null, PackedStringArray(), raw_difficulty).difficulty_filter

func _visible_results_contain(map_id: String) -> bool:
	var normalized_id := map_id.strip_edges().to_upper()
	for map_detail in visible_results:
		if map_detail.map_id == normalized_id:
			return true
	return false

func _selected_package_key() -> String:
	var map_id := selected_map_id.strip_edges().to_upper()
	var version_id := _effective_version_identifier(selected_version_identifier)
	if map_id.is_empty() or version_id.is_empty():
		return ""
	return "%s::%s" % [map_id, version_id.to_lower()]

func _selected_package_record() -> Dictionary:
	var key := _selected_package_key()
	if key.is_empty():
		return {}
	var record: Dictionary = Dictionary(package_records.get(key, {})).duplicate(true)
	if record.is_empty():
		return _build_record_state(_effective_version_identifier(selected_version_identifier), ACTION_DOWNLOAD, 0, {})
	return record

func _set_package_record(key: String, record: Dictionary) -> void:
	if key.is_empty():
		return
	package_records[key] = record.duplicate(true)

func _build_record_state(version_identifier: String, action: String, progress_percent: int, seed_record: Dictionary) -> Dictionary:
	var record := _merge_record(seed_record, {
		"map_id": selected_map_id,
		"version_identifier": version_identifier,
		"action": action,
		"progress_percent": clampi(progress_percent, 0, 100),
		"download_started": action == ACTION_DOWNLOAD,
		"remote_preview_url": _selected_remote_preview_url(),
	})
	if action == ACTION_INSPECT:
		record["download_started"] = true
	return record

func _merge_record(base: Dictionary, patch: Dictionary) -> Dictionary:
	var merged := Dictionary(base).duplicate(true)
	for key in patch.keys():
		merged[key] = patch[key]
	return merged

func _record_has_local_package(record: Dictionary) -> bool:
	var package_dir := String(record.get("package_dir", "")).strip_edges()
	if package_dir.is_empty():
		return false
	return DirAccess.dir_exists_absolute(package_dir) and FileAccess.file_exists(package_dir.path_join("song.package.yaml"))

func _record_has_inspectable_package(record: Dictionary) -> bool:
	return _record_has_local_package(record) and _validation_allows_inspect(Dictionary(record.get("validation", {})))

func _refresh_selected_package_truth() -> void:
	var key := _selected_package_key()
	if key.is_empty():
		return
	var record: Dictionary = _selected_package_record()
	if _record_has_local_package(record):
		_set_package_record(key, _merge_record(record, {
			"action": ACTION_INSPECT if _validation_allows_inspect(Dictionary(record.get("validation", {}))) else ACTION_VALIDATION_FAILED,
			"download_started": true,
			"progress_percent": 100,
		}))
		return
	_set_package_record(key, _merge_record(record, {
		"action": ACTION_DOWNLOAD,
		"download_started": false,
		"progress_percent": 0,
		"local_preview_path": "",
		"local_source_audio_path": "",
	}))

func _effective_version_identifier(version_identifier: String) -> String:
	var effective_identifier := version_identifier.strip_edges()
	if effective_identifier.is_empty():
		effective_identifier = selected_version_identifier.strip_edges()
	if effective_identifier.is_empty() and selected_map != null:
		effective_identifier = selected_map.primary_hash()
	return effective_identifier

func _selected_remote_preview_url() -> String:
	if selected_map == null:
		return ""
	var version = selected_map.find_version(_effective_version_identifier(selected_version_identifier))
	if version == null:
		version = selected_map.latest_version
	return "" if version == null else String(version.preview_url)

func _package_output_root() -> String:
	var normalized_root := artifact_root.strip_edges()
	if normalized_root.begins_with("res://") or normalized_root.begins_with("user://"):
		normalized_root = ProjectSettings.globalize_path(normalized_root)
	return normalized_root.path_join("packages")

func _extract_conversion_error(result: Dictionary, fallback: String) -> String:
	var error_dict := Dictionary(result.get("error", {}))
	if not error_dict.is_empty() and error_dict.has("message"):
		return str(error_dict.get("message", fallback))
	if result.has("message"):
		return str(result.message)
	return fallback

func _validation_allows_inspect(report: Dictionary) -> bool:
	if not bool(report.get("valid", false)):
		return false
	if report.has("delegatedValidator") and String(report.get("delegatedValidator", "")) == "unavailable":
		return false
	return true

func _validation_failure_message(report: Dictionary) -> String:
	var issues: Array = Array(report.get("issues", []))
	if not issues.is_empty():
		return String(Dictionary(issues[0]).get("message", "Converted package validation failed."))
	if String(report.get("delegatedValidator", "unavailable")) == "unavailable":
		return "Converted package validation is unavailable."
	return "Converted package validation failed."

func _extract_local_audio_truth(authoring_state: Dictionary, package_dir: String) -> Dictionary:
	var songs: Array = Array(authoring_state.get("songs", []))
	var song_audio: Dictionary = {}
	if songs.size() > 0:
		song_audio = Dictionary(Dictionary(songs[0]).get("audio", {})).duplicate(true)
	var preview_relative_path := String(song_audio.get("previewFilePath", "")).strip_edges()
	var source_relative_path := String(song_audio.get("filePath", "")).strip_edges()
	var local_preview_path := package_dir.path_join(preview_relative_path) if not preview_relative_path.is_empty() else ""
	if not local_preview_path.is_empty() and not FileAccess.file_exists(local_preview_path):
		local_preview_path = ""
	var local_source_audio_path := package_dir.path_join(source_relative_path) if not source_relative_path.is_empty() else ""
	if not local_source_audio_path.is_empty() and not FileAccess.file_exists(local_source_audio_path):
		local_source_audio_path = ""
	return {
		"song_audio": song_audio,
		"local_preview_path": local_preview_path,
		"local_source_audio_path": local_source_audio_path,
		"remote_preview_url": String(song_audio.get("previewUrl", "")).strip_edges(),
	}

func _open_external(target: String) -> int:
	if shell_opener.is_valid():
		return int(shell_opener.call(target))
	return OS.shell_open(target)

func _on_stage_lifecycle_event(event: Dictionary, package_key: String) -> void:
	var phase := String(event.get("phase", ACTION_DOWNLOAD))
	var record := _selected_package_record() if package_key == _selected_package_key() else Dictionary(package_records.get(package_key, {})).duplicate(true)
	var action := ACTION_DOWNLOAD
	if phase == ACTION_STAGING:
		action = ACTION_STAGING
	_set_package_record(package_key, _merge_record(record, {
		"action": action,
		"download_started": true,
		"remote_preview_url": _selected_remote_preview_url(),
	}))
	emit_signal("state_changed")

func _on_stage_download_progress(event: Dictionary, package_key: String) -> void:
	var record := _selected_package_record() if package_key == _selected_package_key() else Dictionary(package_records.get(package_key, {})).duplicate(true)
	var progress_value := float(event.get("progress", -1.0))
	var progress_percent := int(round(progress_value * 100.0)) if progress_value >= 0.0 else int(record.get("progress_percent", 0))
	_set_package_record(package_key, _merge_record(record, {
		"action": ACTION_DOWNLOAD,
		"download_started": true,
		"progress_percent": clampi(progress_percent, 0, 100),
	}))
	emit_signal("state_changed")
