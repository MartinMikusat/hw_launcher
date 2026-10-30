package settings

import "base:runtime"
import "core:encoding/json"
import "core:strings"

LLM_Snapshot :: struct {
	configs: [dynamic]LLM_Config,
	feature_selections: [LLM_Feature]LLM_Feature_Selection,
	feature_selection_present: [LLM_Feature]bool,
}

LLM_Config_Wire_Row :: struct {
	id: string,
	model: string,
	provider: Maybe([]string),
	is_active: bool,
	label: Maybe(string),
}

LLM_Feature_Selection_Wire_Row :: struct {
	feature: string,
	config_id: string,
}

llm_feature_from_storage_id :: proc(value: string) -> (LLM_Feature, bool) {
	feature := LLM_Feature.Email_Summarization
	for int(feature) < len(LLM_Feature) {
		if llm_feature_storage_id(feature) == value { return feature, true }
		feature = LLM_Feature(int(feature) + 1)
	}
	return {}, false
}

llm_snapshot_decode :: proc(
	configs_body, selections_body: []u8,
	allocator: runtime.Allocator,
) -> (LLM_Snapshot, bool) {
	config_rows: [dynamic]LLM_Config_Wire_Row
	selection_rows: [dynamic]LLM_Feature_Selection_Wire_Row
	if json.unmarshal(configs_body, &config_rows, allocator = allocator) != nil ||
	   json.unmarshal(selections_body, &selection_rows, allocator = allocator) != nil ||
	   len(config_rows) > MAX_LLM_CONFIGS {
		return {}, false
	}
	result := LLM_Snapshot{
		configs = make([dynamic]LLM_Config, 0, len(config_rows), allocator),
	}
	for row in config_rows {
		model := ascii_trim(row.model)
		if len(row.id) == 0 || len(model) == 0 { return {}, false }
		config := LLM_Config{id = row.id, model = model, is_active = row.is_active}
		if providers, present := row.provider.?; present { config.providers = providers }
		if label, present := row.label.?; present { config.label = ascii_trim(label) }
		append(&result.configs, config)
	}
	for row in selection_rows {
		feature, valid := llm_feature_from_storage_id(row.feature)
		if !valid || len(row.config_id) == 0 { continue }
		result.feature_selections[feature] = {feature = feature, config_id = row.config_id}
		result.feature_selection_present[feature] = true
	}
	return result, true
}

llm_provider_input_parse :: proc(
	value: string,
	allocator: runtime.Allocator,
) -> ([]string, bool) {
	trimmed := ascii_trim(value)
	providers := make([dynamic]string, 0, 4, allocator)
	if len(trimmed) == 0 { return providers[:], true }
	start_index := 0
	for end_index := 0; end_index <= len(trimmed); end_index += 1 {
		if end_index < len(trimmed) && trimmed[end_index] != ',' { continue }
		provider := ascii_trim(trimmed[start_index:end_index])
		start_index = end_index+1
		if len(provider) == 0 { continue }
		for byte_value in provider {
			valid := byte_value >= 'a' && byte_value <= 'z' ||
			         byte_value >= 'A' && byte_value <= 'Z' ||
			         byte_value >= '0' && byte_value <= '9' ||
			         byte_value == '-' || byte_value == '_' || byte_value == '/'
			if !valid { return nil, false }
		}
		append(&providers, provider)
	}
	return providers[:], true
}

llm_providers_join :: proc(
	providers: []string,
	allocator: runtime.Allocator,
) -> (string, bool) {
	joined, join_error := strings.join(providers, ",", allocator)
	return joined, join_error == nil
}

llm_config_activate_request :: proc(id: string, query_buffer: []u8) -> (Request_Plan, bool) {
	query, ok := request_query_equal("id", id, "", query_buffer)
	if !ok { return {}, false }
	return {method = .Patch, table = "settings_llm_summarization", query = query, body = "{\"is_active\":true}"}, true
}

llm_config_delete_request :: proc(id: string, query_buffer: []u8) -> (Request_Plan, bool) {
	query, ok := request_query_equal("id", id, "", query_buffer)
	if !ok { return {}, false }
	return {method = .Delete, table = "settings_llm_summarization", query = query}, true
}

llm_config_insert_request :: proc(
	provider_input, model_input, label_input: string,
	is_active: bool,
	body_buffer: []u8,
	allocator: runtime.Allocator,
) -> (Request_Plan, bool) {
	model := ascii_trim(model_input)
	label := ascii_trim(label_input)
	providers, providers_ok := llm_provider_input_parse(provider_input, allocator)
	if len(model) == 0 || !providers_ok { return {}, false }
	writer := Local_JSON_Writer{destination = body_buffer}
	local_json_literal(&writer, "{\"provider\":")
	if len(providers) == 0 {
		local_json_literal(&writer, "null")
	} else {
		local_json_literal(&writer, "[")
		for provider, provider_index in providers {
			if provider_index > 0 { local_json_literal(&writer, ",") }
			local_json_string(&writer, provider)
		}
		local_json_literal(&writer, "]")
	}
	local_json_literal(&writer, ",\"model\":")
	local_json_string(&writer, model)
	local_json_literal(&writer, ",\"label\":")
	if len(label) > 0 { local_json_string(&writer, label) } else { local_json_literal(&writer, "null") }
	local_json_literal(&writer, ",\"is_active\":")
	local_json_literal(&writer, is_active ? "true" : "false")
	local_json_literal(&writer, "}")
	if writer.overflow { return {}, false }
	return {
		method = .Post,
		table = "settings_llm_summarization",
		body = string(body_buffer[:writer.length]),
	}, true
}

llm_feature_selection_upsert_request :: proc(
	feature: LLM_Feature,
	config_id, updated_at: string,
	body_buffer: []u8,
) -> (Request_Plan, bool) {
	feature_id := llm_feature_storage_id(feature)
	if len(feature_id) == 0 || len(config_id) == 0 || len(updated_at) == 0 { return {}, false }
	writer := Local_JSON_Writer{destination = body_buffer}
	local_json_literal(&writer, "{\"feature\":")
	local_json_string(&writer, feature_id)
	local_json_literal(&writer, ",\"config_id\":")
	local_json_string(&writer, config_id)
	local_json_literal(&writer, ",\"updated_at\":")
	local_json_string(&writer, updated_at)
	local_json_literal(&writer, "}")
	if writer.overflow { return {}, false }
	return {
		method = .Post,
		table = "settings_llm_featuremodelselection",
		query = "on_conflict=feature",
		body = string(body_buffer[:writer.length]),
		upsert_resolution_merge_duplicates = true,
	}, true
}
