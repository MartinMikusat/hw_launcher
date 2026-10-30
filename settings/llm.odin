package settings

llm_feature_storage_id :: proc(feature: LLM_Feature) -> string {
	switch feature {
	case .Email_Summarization: return "email_summarization"
	case .Case_Summarization: return "case_summarization"
	case .Location_Matching: return "location_matching"
	case .Knowledge_Article_Generation: return "knowledge_article_generation"
	case .Charger_Diagnostics: return "charger_diagnostics"
	}
	return ""
}

state_replace_llm_configs :: proc(state: ^State, configs: []LLM_Config) -> bool {
	if len(configs) > MAX_LLM_CONFIGS { return false }
	for config_index in 0 ..< state.llm_config_count { state.llm_configs[config_index] = {} }
	for config, config_index in configs { state.llm_configs[config_index] = config }
	state.llm_config_count = len(configs)
	return true
}

state_llm_config_by_id :: proc(state: ^State, id: string) -> ^LLM_Config {
	state_local := state
	for config_index in 0 ..< state.llm_config_count {
		if state.llm_configs[config_index].id == id { return &state_local.llm_configs[config_index] }
	}
	return nil
}

state_llm_config_for_feature :: proc(state: ^State, feature: LLM_Feature) -> ^LLM_Config {
	selection := &state.feature_selections[feature]
	if selection.feature != feature || len(selection.config_id) == 0 { return nil }
	return state_llm_config_by_id(state, selection.config_id)
}

state_set_feature_selection :: proc(state: ^State, feature: LLM_Feature, config_id: string) -> bool {
	if state_llm_config_by_id(state, config_id) == nil { return false }
	state.feature_selections[feature] = {feature = feature, config_id = config_id}
	return true
}

llm_config_duplicate :: proc(state: ^State, model: string, providers: []string) -> bool {
	state_local := state
	for config_index in 0 ..< state.llm_config_count {
		config := &state_local.llm_configs[config_index]
		if config.model != model || len(config.providers) != len(providers) { continue }
		matched := true
		for provider_index in 0 ..< len(providers) {
			if config.providers[provider_index] != providers[provider_index] { matched = false; break }
		}
		if matched { return true }
	}
	return false
}
