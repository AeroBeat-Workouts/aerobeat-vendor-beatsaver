class_name BeatSaverVendorFacade
extends RefCounted

const BeatSaverHttpClient = preload("res://../src/client/beatsaver_http_client.gd")
const BeatSaverRequestBuilder = preload("res://../src/client/beatsaver_request_builder.gd")
const BeatSaverResponseParser = preload("res://../src/client/beatsaver_response_parser.gd")
const BeatSaverSearchQuery = preload("res://../src/models/beatsaver_search_query.gd")

var _http_client: BeatSaverHttpClient
var _request_builder: BeatSaverRequestBuilder
var _response_parser: BeatSaverResponseParser

func _init(http_client: BeatSaverHttpClient = null, request_builder: BeatSaverRequestBuilder = null, response_parser: BeatSaverResponseParser = null) -> void:
	_http_client = http_client if http_client != null else BeatSaverHttpClient.new()
	_request_builder = request_builder if request_builder != null else BeatSaverRequestBuilder.new()
	_response_parser = response_parser if response_parser != null else BeatSaverResponseParser.new()

func search_maps(query: BeatSaverSearchQuery, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_search_request(query), Callable(_response_parser, "parse_search_response"), options)

func fetch_map_detail_by_id(map_id: String, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_map_detail_by_id_request(map_id), Callable(_response_parser, "parse_map_detail"), options)

func fetch_map_detail_by_hash(map_hash: String, options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_map_detail_by_hash_request(map_hash), Callable(_response_parser, "parse_map_detail"), options)

func list_latest_maps(options: Dictionary = {}) -> Dictionary:
	return _execute_and_parse(_request_builder.build_latest_maps_request(options), Callable(_response_parser, "parse_latest_response"), options)

func _execute_and_parse(request: Dictionary, parser: Callable, options: Dictionary) -> Dictionary:
	var transport := _http_client.execute(request, options)
	if not transport.ok:
		return transport
	transport["data"] = parser.call(transport.payload if transport.payload is Dictionary else {})
	return transport
