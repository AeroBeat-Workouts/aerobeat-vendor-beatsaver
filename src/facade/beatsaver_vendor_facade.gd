class_name BeatSaverVendorFacade
extends RefCounted

const BeatSaverArchiveInspector = preload("res://../src/acquisition/beatsaver_archive_inspector.gd")
const BeatSaverPackageFetcher = preload("res://../src/acquisition/beatsaver_package_fetcher.gd")
const BeatSaverStageManifestBuilder = preload("res://../src/acquisition/beatsaver_stage_manifest_builder.gd")
const BeatSaverHttpClient = preload("res://../src/client/beatsaver_http_client.gd")
const BeatSaverRequestBuilder = preload("res://../src/client/beatsaver_request_builder.gd")
const BeatSaverResponseParser = preload("res://../src/client/beatsaver_response_parser.gd")
const BeatSaverMapDetail = preload("res://../src/models/beatsaver_map_detail.gd")
const BeatSaverSearchQuery = preload("res://../src/models/beatsaver_search_query.gd")
const BeatSaverVersionRef = preload("res://../src/models/beatsaver_version_ref.gd")

var _http_client: BeatSaverHttpClient
var _request_builder: BeatSaverRequestBuilder
var _response_parser: BeatSaverResponseParser
var _package_fetcher: BeatSaverPackageFetcher
var _archive_inspector: BeatSaverArchiveInspector
var _manifest_builder: BeatSaverStageManifestBuilder

func _init(http_client: BeatSaverHttpClient = null, request_builder: BeatSaverRequestBuilder = null, response_parser: BeatSaverResponseParser = null, package_fetcher: BeatSaverPackageFetcher = null, archive_inspector: BeatSaverArchiveInspector = null, manifest_builder: BeatSaverStageManifestBuilder = null) -> void:
	_http_client = http_client if http_client != null else BeatSaverHttpClient.new()
	_request_builder = request_builder if request_builder != null else BeatSaverRequestBuilder.new()
	_response_parser = response_parser if response_parser != null else BeatSaverResponseParser.new()
	_package_fetcher = package_fetcher if package_fetcher != null else BeatSaverPackageFetcher.new(_http_client)
	_archive_inspector = archive_inspector if archive_inspector != null else BeatSaverArchiveInspector.new()
	_manifest_builder = manifest_builder if manifest_builder != null else BeatSaverStageManifestBuilder.new()

func search_maps(query: BeatSaverSearchQuery, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_search_request(query), Callable(_response_parser, "parse_search_response"), options)

func fetch_map_detail_by_id(map_id: String, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_map_detail_by_id_request(map_id), Callable(_response_parser, "parse_map_detail"), options)

func fetch_map_detail_by_hash(map_hash: String, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_map_detail_by_hash_request(map_hash), Callable(_response_parser, "parse_map_detail"), options)

func list_latest_maps(options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_latest_maps_request(options), Callable(_response_parser, "parse_latest_response"), options)

func stage_selected_version_artifact(map_detail: BeatSaverMapDetail, version_selector: Variant = null, staging_root: String = "res://.artifacts", options: Dictionary = {}) -> Dictionary:
	if map_detail == null:
		return _error_result("map_detail is required")
	var version_ref := _resolve_version_ref(map_detail, version_selector)
	if version_ref == null:
		return _error_result("Could not resolve the requested BeatSaver version for staging.")
	var lifecycle_callback: Callable = options.get("lifecycle_callback", Callable())
	if lifecycle_callback.is_valid():
		lifecycle_callback.call({
			"phase": "download",
			"map_id": map_detail.map_id,
			"version_hash": version_ref.hash,
		})
	var stage_result := _package_fetcher.fetch_version_package(map_detail, version_ref, staging_root, options)
	if not stage_result.get("ok", false):
		return stage_result
	if lifecycle_callback.is_valid():
		lifecycle_callback.call({
			"phase": "staging",
			"map_id": map_detail.map_id,
			"version_hash": version_ref.hash,
			"archive_path": str(stage_result.get("archive_path", "")),
			"stage_directory_path": str(stage_result.get("stage_directory_path", "")),
		})
	var archive_report := _archive_inspector.inspect_archive(str(stage_result.get("archive_path", "")))
	if not archive_report.get("ok", false):
		return archive_report
	var manifest = _manifest_builder.build_manifest(map_detail, version_ref, stage_result, archive_report)
	var manifest_path := "%s/%s" % [str(stage_result.get("stage_directory_path", "")).rstrip("/"), str(options.get("manifest_file_name", "source_material_manifest.json"))]
	var save_result := _manifest_builder.save_manifest(manifest, manifest_path)
	if not save_result.get("ok", false):
		return save_result
	return {
		"ok": true,
		"data": {
			"stage": stage_result,
			"archive": archive_report,
			"manifest": manifest.to_dictionary()
		}
	}

func _execute_and_parse(request: Dictionary, parser: Callable, options: Dictionary) -> Dictionary:
	var transport := _http_client.execute(request, options)
	if not transport.ok:
		return transport
	transport["data"] = parser.call(transport.payload if transport.payload is Dictionary else {})
	return transport

func _resolve_version_ref(map_detail: BeatSaverMapDetail, version_selector: Variant) -> BeatSaverVersionRef:
	if version_selector == null:
		return map_detail.latest_version
	if version_selector is BeatSaverVersionRef:
		return version_selector
	var identifier := str(version_selector).strip_edges()
	if identifier.is_empty():
		return map_detail.latest_version
	return map_detail.find_version(identifier)

func _error_result(message: String, code: int = ERR_INVALID_PARAMETER) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"category": "acquisition",
			"message": message,
			"code": code
		}
	}
