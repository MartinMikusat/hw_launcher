package settings

import "base:runtime"
import "core:encoding/json"

Request_Method :: enum u8 {
	Get,
	Post,
	Patch,
	Delete,
}

Request_Plan :: struct {
	method: Request_Method,
	table:  string,
	query:  string,
	body:   string,
	upsert_resolution_merge_duplicates: bool,
	return_representation: bool,
}

prepare_l2_folder_load_request :: proc(user_id: string, query_buffer: []u8) -> (Request_Plan, bool) {
	query, ok := request_query_equal("user_id", user_id, "select=folder_path&", query_buffer)
	if !ok { return {}, false }
	return {method = .Get, table = "settings_prepareforl2_folder", query = query}, true
}

prepare_l2_folder_delete_request :: proc(user_id: string, query_buffer: []u8) -> (Request_Plan, bool) {
	query, ok := request_query_equal("user_id", user_id, "", query_buffer)
	if !ok { return {}, false }
	return {method = .Delete, table = "settings_prepareforl2_folder", query = query}, true
}

prepare_l2_folder_upsert_request :: proc(
	user_id, folder_path: string,
	query_buffer, body_buffer: []u8,
) -> (Request_Plan, bool) {
	if len(user_id) == 0 || len(folder_path) == 0 { return {}, false }
	query_value := "on_conflict=user_id"
	if len(query_value) > len(query_buffer) { return {}, false }
	for byte_value, byte_index in query_value { query_buffer[byte_index] = u8(byte_value) }

	writer := Local_JSON_Writer{destination = body_buffer}
	local_json_literal(&writer, "{\"user_id\":")
	local_json_string(&writer, user_id)
	local_json_literal(&writer, ",\"folder_path\":")
	local_json_string(&writer, folder_path)
	local_json_literal(&writer, "}")
	if writer.overflow { return {}, false }
	return {
		method = .Post,
		table = "settings_prepareforl2_folder",
		query = string(query_buffer[:len(query_value)]),
		body = string(body_buffer[:writer.length]),
		upsert_resolution_merge_duplicates = true,
	}, true
}

Prepare_L2_Folder_Wire :: struct {
	folder_path: Maybe(string),
}

prepare_l2_folder_decode :: proc(
	body: []u8,
	allocator: runtime.Allocator,
) -> (string, bool) {
	rows: [dynamic]Prepare_L2_Folder_Wire
	if json.unmarshal(body, &rows, allocator = allocator) != nil || len(rows) > 1 {
		return "", false
	}
	if len(rows) == 0 { return "", true }
	if folder_path, present := rows[0].folder_path.?; present {
		return ascii_trim(folder_path), true
	}
	return "", true
}

Version_Config_Wire_Row :: struct {
	id:             string,
	min_version:    string,
	latest_version: string,
	download_url:   Maybe(string),
	updated_at:     string,
}

version_config_decode :: proc(
	body: []u8,
	allocator: runtime.Allocator,
) -> (Version_Config, bool) {
	rows: [dynamic]Version_Config_Wire_Row
	if json.unmarshal(body, &rows, allocator = allocator) != nil || len(rows) != 1 {
		return {}, false
	}
	row := &rows[0]
	result := Version_Config{
		id = row.id,
		min_version = ascii_trim(row.min_version),
		latest_version = ascii_trim(row.latest_version),
		updated_at = row.updated_at,
	}
	if download_url, present := row.download_url.?; present {
		result.download_url = ascii_trim(download_url)
		result.has_download_url = len(result.download_url) > 0
	}
	return result, len(result.id) > 0 && version_config_is_valid(&result)
}

version_config_update_request :: proc(
	config: ^Version_Config,
	updated_at: string,
	query_buffer, body_buffer: []u8,
) -> (Request_Plan, bool) {
	if config == nil || len(config.id) == 0 || len(updated_at) == 0 ||
	   !version_config_is_valid(config) {
		return {}, false
	}
	query, query_ok := request_query_equal("id", config.id, "", query_buffer)
	if !query_ok { return {}, false }
	writer := Local_JSON_Writer{destination = body_buffer}
	local_json_literal(&writer, "{\"min_version\":")
	local_json_string(&writer, config.min_version)
	local_json_literal(&writer, ",\"latest_version\":")
	local_json_string(&writer, config.latest_version)
	local_json_literal(&writer, ",\"download_url\":")
	if config.has_download_url && len(config.download_url) > 0 {
		local_json_string(&writer, config.download_url)
	} else {
		local_json_literal(&writer, "null")
	}
	local_json_literal(&writer, ",\"updated_at\":")
	local_json_string(&writer, updated_at)
	local_json_literal(&writer, "}")
	if writer.overflow { return {}, false }
	return {
		method = .Patch,
		table = "app_version_config",
		query = query,
		body = string(body_buffer[:writer.length]),
	}, true
}

version_config_load_request :: proc(admin_edit: bool) -> Request_Plan {
	if admin_edit {
		return {
			method = .Get,
			table = "app_version_config",
			query = "select=id,min_version,latest_version,download_url,updated_at&order=updated_at.desc&limit=1",
		}
	}
	return {
		method = .Get,
		table = "app_version_config",
		query = "select=min_version,latest_version,download_url,updated_at&order=updated_at.desc&limit=1",
	}
}

diagnostics_distinct_cases_request :: proc() -> Request_Plan {
	return {
		method = .Get,
		table = "exported_cases",
		query = "select=queue_name,owner_name,status",
	}
}

diagnostics_configuration_load_requests :: proc(destination: []Request_Plan) -> int {
	if len(destination) < 3 { return 0 }
	destination[0] = {method = .Get, table = "diagnostics_case_queues", query = "select=queue_name&order=queue_name.asc"}
	destination[1] = {method = .Get, table = "diagnostics_case_owners", query = "select=owner_name&order=owner_name.asc"}
	destination[2] = {method = .Get, table = "diagnostics_case_statuses", query = "select=status_name&order=status_name.asc"}
	return 3
}

llm_configs_load_request :: proc() -> Request_Plan {
	return {method = .Get, table = "settings_llm_summarization", query = "select=*&order=created_at.asc"}
}

llm_feature_selections_load_request :: proc() -> Request_Plan {
	return {method = .Get, table = "settings_llm_featuremodelselection", query = "select=*&order=feature.asc"}
}

request_query_equal :: proc(
	field, value, prefix: string,
	destination: []u8,
) -> (string, bool) {
	required_length := len(prefix)+len(field)+4+len(value)
	if required_length > len(destination) { return "", false }
	write_index := 0
	parts := []string{prefix, field, "=eq.", value}
	for part in parts {
		for byte_index in 0 ..< len(part) { destination[write_index] = part[byte_index]; write_index += 1 }
	}
	return string(destination[:write_index]), true
}
