package settings

state_default :: proc() -> State {
	return {
		selected_tab = .General,
		theme = .Light,
		root_font_pixels = 13,
		search_scroll_speed_percent = 100,
		cabinet_default_tab = .Diagnostics,
		service_visits_display_mode = .List,
	}
}

state_set_theme :: proc(state: ^State, theme: Theme) -> Persistence_Action {
	state.theme = theme
	return {kind = .Write_Device_Preferences, value = theme_definition(theme).storage_id}
}

state_set_root_font_pixels :: proc(state: ^State, value: int) -> Persistence_Action {
	state.root_font_pixels = root_font_pixels_clamp(value)
	return {kind = .Write_Device_Preferences}
}

state_set_cabinet_default_tab :: proc(
	state: ^State,
	default_tab: Charger_Default_Tab,
) -> Persistence_Action {
	state.cabinet_default_tab = default_tab
	return {kind = .Write_Device_Preferences}
}

state_set_report_output_folder :: proc(state: ^State, value: string) -> Persistence_Action {
	next := ascii_trim(value)
	state.paths.report_output_folder = next
	if len(next) == 0 { return {kind = .Delete_Report_Output_File} }
	return {kind = .Write_Report_Output_File, value = next}
}

state_set_log_files_cache_root :: proc(state: ^State, value: string) -> Persistence_Action {
	next := ascii_trim(value)
	state.paths.log_files_cache_root = next
	if len(next) == 0 { return {kind = .Delete_Log_Cache_File} }
	return {kind = .Write_Log_Cache_File, value = next}
}

state_set_prepare_l2_output_folder :: proc(state: ^State, value: string) -> Persistence_Action {
	next := ascii_trim(value)
	state.paths.prepare_for_l2_output_folder = next
	if len(next) == 0 { return {kind = .Delete_Prepare_L2_Folder} }
	return {kind = .Upsert_Prepare_L2_Folder, value = next}
}

state_effective_report_folder :: proc(state: ^State, desktop_path: string) -> string {
	if len(state.paths.report_output_folder) > 0 { return state.paths.report_output_folder }
	return desktop_path
}

state_effective_log_cache_root :: proc(state: ^State, user_data_path: string, buffer: []u8) -> (string, bool) {
	if len(state.paths.log_files_cache_root) > 0 { return state.paths.log_files_cache_root, true }
	return path_join(user_data_path, "logFiles", buffer)
}

state_effective_prepare_l2_folder :: proc(state: ^State, desktop_path: string) -> string {
	if len(state.paths.prepare_for_l2_output_folder) > 0 { return state.paths.prepare_for_l2_output_folder }
	return desktop_path
}

charger_default_tab_storage_id :: proc(value: Charger_Default_Tab) -> string {
	switch value {
	case .Diagnostics: return "diagnostics"
	case .Statistics: return "statistics"
	case .Detailed: return "detailed"
	case .Location: return "location"
	case .Plug_Logs: return "plugLogs"
	case .Sessions: return "sessions"
	case .Config: return "config"
	case .Config_History: return "configHistory"
	case .Archived_Logs: return "archivedLogs"
	case .Charger_Events: return "chargerEvents"
	case .State_Machine: return "stateMachine"
	case .Teltonika_Config: return "teltonikaConfig"
	}
	return "diagnostics"
}

charger_default_tab_from_storage_id :: proc(value: string) -> Charger_Default_Tab {
	candidate := Charger_Default_Tab.Diagnostics
	for int(candidate) <= int(Charger_Default_Tab.Teltonika_Config) {
		if charger_default_tab_storage_id(candidate) == value { return candidate }
		candidate = Charger_Default_Tab(int(candidate) + 1)
	}
	return .Diagnostics
}

ascii_trim :: proc(value: string) -> string {
	start_index := 0
	for start_index < len(value) && ascii_whitespace(value[start_index]) { start_index += 1 }
	end_index := len(value)
	for end_index > start_index && ascii_whitespace(value[end_index-1]) { end_index -= 1 }
	return value[start_index:end_index]
}

ascii_whitespace :: proc(value: u8) -> bool {
	return value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

path_join :: proc(left, right: string, destination: []u8) -> (string, bool) {
	separator_needed := len(left) > 0 && left[len(left)-1] != '\\' && left[len(left)-1] != '/'
	required_length := len(left)+len(right)+(separator_needed ? 1 : 0)
	if required_length > len(destination) { return "", false }
	write_index := 0
	for byte_index in 0 ..< len(left) { destination[write_index] = left[byte_index]; write_index += 1 }
	if separator_needed { destination[write_index] = '\\'; write_index += 1 }
	for byte_index in 0 ..< len(right) { destination[write_index] = right[byte_index]; write_index += 1 }
	return string(destination[:write_index]), true
}
