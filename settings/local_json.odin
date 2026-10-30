package settings

import "core:encoding/json"

Sessions_Mode :: enum u8 {Simple, Full}
SEARCH_SCROLL_SPEED_PERCENT_MIN :: 10
SEARCH_SCROLL_SPEED_PERCENT_MAX :: 1000

Local_JSON_Error :: enum u8 {
	None,
	Malformed,
	Buffer_Too_Small,
}

Device_Preferences :: struct {
	theme:                       Theme,
	root_font_pixels:            int,
	search_scroll_speed_percent: int,
	cabinet_default_tab:         Charger_Default_Tab,
	service_visits_display_mode: Service_Visits_Display_Mode,
	sessions_mode:               Sessions_Mode,
	hints_hidden:                bool,
	admin_enabled:               bool,
}

device_preferences_from_state :: proc(state: ^State) -> Device_Preferences {
	return {
		theme = state.theme,
		root_font_pixels = state.root_font_pixels,
		search_scroll_speed_percent = state.search_scroll_speed_percent,
		cabinet_default_tab = state.cabinet_default_tab,
		service_visits_display_mode = state.service_visits_display_mode,
	}
}

service_visits_display_mode_storage_id :: proc(value: Service_Visits_Display_Mode) -> string {
	switch value {
	case .List: return "list"
	case .Timeline: return "timeline"
	}
	return "list"
}

service_visits_display_mode_from_storage_id :: proc(value: string) -> Service_Visits_Display_Mode {
	if value == "timeline" { return .Timeline }
	return .List
}

device_preferences_write_json :: proc(
	preferences: ^Device_Preferences,
	destination: []u8,
) -> (int, Local_JSON_Error) {
	writer := Local_JSON_Writer {destination = destination}
	local_json_literal(&writer, "{\n  \"theme\": ")
	local_json_string(&writer, theme_definition(preferences.theme).storage_id)
	local_json_literal(&writer, ",\n  \"root_font_pixels\": ")
	local_json_integer(&writer, root_font_pixels_clamp(preferences.root_font_pixels))
	local_json_literal(&writer, ",\n  \"search_scroll_speed_percent\": ")
	local_json_integer(&writer, clamp(preferences.search_scroll_speed_percent, SEARCH_SCROLL_SPEED_PERCENT_MIN, SEARCH_SCROLL_SPEED_PERCENT_MAX))
	local_json_literal(&writer, ",\n  \"cabinet_default_tab\": ")
	local_json_string(&writer, charger_default_tab_storage_id(preferences.cabinet_default_tab))
	local_json_literal(&writer, ",\n  \"service_visits_display_mode\": ")
	local_json_string(&writer, service_visits_display_mode_storage_id(preferences.service_visits_display_mode))
	local_json_literal(&writer, ",\n  \"sessions_mode\": ")
	local_json_string(&writer, preferences.sessions_mode == .Full ? "full" : "simple")
	local_json_literal(&writer, ",\n  \"hints_hidden\": ")
	local_json_literal(&writer, preferences.hints_hidden ? "true" : "false")
	local_json_literal(&writer, ",\n  \"admin_enabled\": ")
	local_json_literal(&writer, preferences.admin_enabled ? "true" : "false")
	local_json_literal(&writer, "\n}\n")
	if writer.overflow { return 0, .Buffer_Too_Small }
	return writer.length, .None
}

device_preferences_parse_json :: proc(input: string) -> (Device_Preferences, Local_JSON_Error) {
	preferences := Device_Preferences{theme = .Light, root_font_pixels = 13, search_scroll_speed_percent = 100, cabinet_default_tab = .Diagnostics}
	wire := struct {
		theme: string,
		root_font_pixels: int,
		search_scroll_speed_percent: int,
		cabinet_default_tab: string,
		service_visits_display_mode: string,
		sessions_mode: string,
		hints_hidden: bool,
		admin_enabled: bool,
	}{root_font_pixels = 13, search_scroll_speed_percent = 100}
	trimmed := ascii_trim(input)
	if len(trimmed) == 0 || trimmed[0] != '{' ||
	   json.unmarshal(transmute([]u8)trimmed, &wire, allocator = context.temp_allocator) != nil {
		return preferences, .Malformed
	}
	preferences.theme = theme_from_storage_id(wire.theme)
	preferences.root_font_pixels = root_font_pixels_clamp(wire.root_font_pixels)
	preferences.search_scroll_speed_percent = clamp(wire.search_scroll_speed_percent, SEARCH_SCROLL_SPEED_PERCENT_MIN, SEARCH_SCROLL_SPEED_PERCENT_MAX)
	preferences.cabinet_default_tab = charger_default_tab_from_storage_id(wire.cabinet_default_tab)
	preferences.service_visits_display_mode = service_visits_display_mode_from_storage_id(wire.service_visits_display_mode)
	preferences.sessions_mode = wire.sessions_mode == "full" ? .Full : .Simple
	preferences.hints_hidden = wire.hints_hidden
	preferences.admin_enabled = wire.admin_enabled
	return preferences, .None
}

path_setting_write_json :: proc(
	key, value: string,
	destination: []u8,
) -> (int, Local_JSON_Error) {
	writer := Local_JSON_Writer {destination = destination}
	local_json_literal(&writer, "{\n  ")
	local_json_string(&writer, key)
	local_json_literal(&writer, ": ")
	local_json_string(&writer, value)
	local_json_literal(&writer, "\n}\n")
	if writer.overflow { return 0, .Buffer_Too_Small }
	return writer.length, .None
}

path_setting_parse_json :: proc(
	input, key: string,
	destination: []u8,
) -> (string, bool) {
	wire: map[string]string
	if json.unmarshal(transmute([]u8)input, &wire, allocator = context.temp_allocator) != nil {return "", false}
	value, found := wire[key]
	if !found || len(value) > len(destination) {return "", false}
	copy(destination, value)
	return string(destination[:len(value)]), true
}

Local_JSON_Writer :: struct {
	destination: []u8,
	length:      int,
	overflow:    bool,
}

local_json_literal :: proc(writer: ^Local_JSON_Writer, value: string) {
	for byte_index in 0 ..< len(value) { local_json_byte(writer, value[byte_index]) }
}

local_json_string :: proc(writer: ^Local_JSON_Writer, value: string) {
	local_json_byte(writer, '"')
	for byte_index in 0 ..< len(value) {
		value_byte := value[byte_index]
		switch value_byte {
		case '"': local_json_literal(writer, "\\\"")
		case '\\': local_json_literal(writer, "\\\\")
		case '\n': local_json_literal(writer, "\\n")
		case '\r': local_json_literal(writer, "\\r")
		case '\t': local_json_literal(writer, "\\t")
		case:
			if value_byte >= 0x20 { local_json_byte(writer, value_byte) }
		}
	}
	local_json_byte(writer, '"')
}

local_json_integer :: proc(writer: ^Local_JSON_Writer, value: int) {
	remaining := value
	if remaining < 0 { local_json_byte(writer, '-'); remaining = -remaining }
	digits: [32]u8
	digit_count := 0
	if remaining == 0 { local_json_byte(writer, '0'); return }
	for remaining > 0 { digits[digit_count] = u8(remaining%10)+'0'; digit_count += 1; remaining /= 10 }
	for digit_index := digit_count-1; digit_index >= 0; digit_index -= 1 {
		local_json_byte(writer, digits[digit_index])
	}
}

local_json_byte :: proc(writer: ^Local_JSON_Writer, value: u8) {
	if writer.length >= len(writer.destination) { writer.overflow = true; return }
	writer.destination[writer.length] = value
	writer.length += 1
}
