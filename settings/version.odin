package settings

Semantic_Version :: struct {
	major: int,
	minor: int,
	patch: int,
}

Version_Gate :: enum u8 {
	Allowed,
	Update_Available,
	Blocked_Minimum,
}

semantic_version_parse :: proc(value: string) -> (Semantic_Version, bool) {
	if len(value) == 0 { return {}, false }
	parts: [3]int
	part_start := 0
	for part_index in 0 ..< 3 {
		part_end := part_start
		for part_end < len(value) && value[part_end] != '.' { part_end += 1 }
		if part_end == part_start { return {}, false }
		if part_index < 2 && part_end >= len(value) { return {}, false }
		if part_index == 2 && part_end != len(value) { return {}, false }
		parsed, ok := semantic_version_parse_numeric_token(value[part_start:part_end])
		if !ok { return {}, false }
		parts[part_index] = parsed
		part_start = part_end+1
	}
	return {major = parts[0], minor = parts[1], patch = parts[2]}, true
}

semantic_version_parse_numeric_token :: proc(value: string) -> (int, bool) {
	if len(value) == 0 || len(value) > 9 { return 0, false }
	result := 0
	for byte_value in value {
		if byte_value < '0' || byte_value > '9' { return 0, false }
		result = result*10+int(byte_value-'0')
	}
	return result, true
}

semantic_version_compare :: proc(left, right: Semantic_Version) -> int {
	if left.major != right.major { return left.major < right.major ? -1 : 1 }
	if left.minor != right.minor { return left.minor < right.minor ? -1 : 1 }
	if left.patch != right.patch { return left.patch < right.patch ? -1 : 1 }
	return 0
}

version_gate :: proc(current_version: string, config: ^Version_Config, admin: bool) -> Version_Gate {
	current, current_ok := semantic_version_parse(current_version)
	minimum, minimum_ok := semantic_version_parse(config.min_version)
	latest, latest_ok := semantic_version_parse(config.latest_version)
	if !current_ok || !minimum_ok || !latest_ok { return .Allowed }
	if !admin && semantic_version_compare(current, minimum) < 0 { return .Blocked_Minimum }
	if semantic_version_compare(current, latest) < 0 { return .Update_Available }
	return .Allowed
}

version_config_is_valid :: proc(config: ^Version_Config) -> bool {
	minimum, minimum_ok := semantic_version_parse(config.min_version)
	latest, latest_ok := semantic_version_parse(config.latest_version)
	return minimum_ok && latest_ok && semantic_version_compare(minimum, latest) <= 0
}
