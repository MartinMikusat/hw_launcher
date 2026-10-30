package settings

import "base:runtime"
import crypto_hash "core:crypto/hash"
import "core:encoding/json"
import "core:net"
import "core:slice"

DIAGNOSTICS_VALUE_KIND_COUNT :: 3
DIAGNOSTICS_SELECTION_WORD_COUNT :: 4
DIAGNOSTICS_FINGERPRINT_BYTES :: 32

Diagnostics_Value_Kind :: enum u8 {
	Queue,
	Owner,
	Status,
}

Diagnostics_Selection :: [DIAGNOSTICS_SELECTION_WORD_COUNT]u64

Diagnostics_Value_Set :: struct {
	configured: [dynamic]string,
	available: [dynamic]string,
}

Diagnostics_Config_Snapshot :: struct {
	values: [DIAGNOSTICS_VALUE_KIND_COUNT]Diagnostics_Value_Set,
}

Diagnostics_Queue_Wire_Row :: struct { queue_name: string }
Diagnostics_Owner_Wire_Row :: struct { owner_name: string }
Diagnostics_Status_Wire_Row :: struct { status_name: string }

diagnostics_value_table :: proc(kind: Diagnostics_Value_Kind) -> string {
	switch kind {
	case .Queue: return "diagnostics_case_queues"
	case .Owner: return "diagnostics_case_owners"
	case .Status: return "diagnostics_case_statuses"
	}
	return ""
}

diagnostics_value_column :: proc(kind: Diagnostics_Value_Kind) -> string {
	switch kind {
	case .Queue: return "queue_name"
	case .Owner: return "owner_name"
	case .Status: return "status_name"
	}
	return ""
}

diagnostics_load_requests :: proc(destination: []Request_Plan) -> int {
	if len(destination) < 6 { return 0 }
	configured: [3]Request_Plan
	if diagnostics_configuration_load_requests(configured[:]) != 3 { return 0 }
	destination[0] = configured[0]
	destination[1] = {method = .Get, table = "diagnostics_available_case_queues", query = "select=queue_name&order=queue_name.asc"}
	destination[2] = configured[1]
	destination[3] = {method = .Get, table = "diagnostics_available_case_owners", query = "select=owner_name&order=owner_name.asc"}
	destination[4] = configured[2]
	destination[5] = {method = .Get, table = "diagnostics_available_case_statuses", query = "select=status_name&order=status_name.asc"}
	return 6
}

diagnostics_queue_rows_decode :: proc(body: []u8, allocator: runtime.Allocator) -> ([dynamic]string, bool) {
	rows: [dynamic]Diagnostics_Queue_Wire_Row
	if json.unmarshal(body, &rows, allocator = allocator) != nil || len(rows) > MAX_DIAGNOSTIC_VALUES { return nil, false }
	values := make([dynamic]string, 0, len(rows), allocator)
	for row in rows { if len(row.queue_name) > 0 { append(&values, row.queue_name) } }
	return values, true
}

diagnostics_owner_rows_decode :: proc(body: []u8, allocator: runtime.Allocator) -> ([dynamic]string, bool) {
	rows: [dynamic]Diagnostics_Owner_Wire_Row
	if json.unmarshal(body, &rows, allocator = allocator) != nil || len(rows) > MAX_DIAGNOSTIC_VALUES { return nil, false }
	values := make([dynamic]string, 0, len(rows), allocator)
	for row in rows { if len(row.owner_name) > 0 { append(&values, row.owner_name) } }
	return values, true
}

diagnostics_status_rows_decode :: proc(body: []u8, allocator: runtime.Allocator) -> ([dynamic]string, bool) {
	rows: [dynamic]Diagnostics_Status_Wire_Row
	if json.unmarshal(body, &rows, allocator = allocator) != nil || len(rows) > MAX_DIAGNOSTIC_VALUES { return nil, false }
	values := make([dynamic]string, 0, len(rows), allocator)
	for row in rows { if len(row.status_name) > 0 { append(&values, row.status_name) } }
	return values, true
}

diagnostics_snapshot_decode :: proc(
	bodies: [6][]u8,
	allocator: runtime.Allocator,
) -> (Diagnostics_Config_Snapshot, bool) {
	result: Diagnostics_Config_Snapshot
	queue_configured, queue_configured_ok := diagnostics_queue_rows_decode(bodies[0], allocator)
	queue_available, queue_available_ok := diagnostics_queue_rows_decode(bodies[1], allocator)
	owner_configured, owner_configured_ok := diagnostics_owner_rows_decode(bodies[2], allocator)
	owner_available, owner_available_ok := diagnostics_owner_rows_decode(bodies[3], allocator)
	status_configured, status_configured_ok := diagnostics_status_rows_decode(bodies[4], allocator)
	status_available, status_available_ok := diagnostics_status_rows_decode(bodies[5], allocator)
	if !queue_configured_ok || !queue_available_ok || !owner_configured_ok ||
	   !owner_available_ok || !status_configured_ok || !status_available_ok {
		return {}, false
	}
	result.values[int(Diagnostics_Value_Kind.Queue)] = {configured = queue_configured, available = queue_available}
	result.values[int(Diagnostics_Value_Kind.Owner)] = {configured = owner_configured, available = owner_available}
	result.values[int(Diagnostics_Value_Kind.Status)] = {configured = status_configured, available = status_available}
	return result, true
}

diagnostics_selection_get :: proc(selection: ^Diagnostics_Selection, index: int) -> bool {
	if selection == nil || index < 0 || index >= MAX_DIAGNOSTIC_VALUES { return false }
	return selection[index/64] & (u64(1)<<u64(index%64)) != 0
}

diagnostics_selection_set :: proc(selection: ^Diagnostics_Selection, index: int, selected: bool) -> bool {
	if selection == nil || index < 0 || index >= MAX_DIAGNOSTIC_VALUES { return false }
	bit := u64(1)<<u64(index%64)
	if selected { selection[index/64] |= bit } else { selection[index/64] &~= bit }
	return true
}

diagnostics_selection_from_values :: proc(values: ^Diagnostics_Value_Set) -> Diagnostics_Selection {
	result: Diagnostics_Selection
	if values == nil { return result }
	for value, value_index in values.available {
		if slice.contains(values.configured[:], value) { _ = diagnostics_selection_set(&result, value_index, true) }
	}
	return result
}

diagnostics_value_index :: proc(values: []string, value: string) -> (int, bool) {
	for candidate, candidate_index in values { if candidate == value { return candidate_index, true } }
	return -1, false
}

diagnostics_available_fingerprint :: proc(
	values: []string,
	destination: []u8,
	allocator: runtime.Allocator,
) -> bool {
	if len(destination) < DIAGNOSTICS_FINGERPRINT_BYTES { return false }
	serialized_length := len(values)*8
	for value in values { serialized_length += len(value) }
	serialized := make([]u8, serialized_length, allocator)
	write_index := 0
	for value in values {
		value_length := u64(len(value))
		for byte_index in 0..<8 {
			serialized[write_index] = u8(value_length>>(u64(byte_index)*8))
			write_index += 1
		}
		copy(serialized[write_index:], transmute([]u8)value)
		write_index += len(value)
	}
	digest := crypto_hash.hash_bytes_to_buffer(.SHA256, serialized, destination)
	return len(digest) == DIAGNOSTICS_FINGERPRINT_BYTES
}

diagnostics_insert_request :: proc(
	kind: Diagnostics_Value_Kind,
	values: []string,
	created_by: string,
	body_buffer: []u8,
) -> (Request_Plan, bool) {
	if len(values) == 0 { return {}, false }
	column := diagnostics_value_column(kind)
	table := diagnostics_value_table(kind)
	if len(column) == 0 || len(table) == 0 { return {}, false }
	writer := Local_JSON_Writer{destination = body_buffer}
	local_json_literal(&writer, "[")
	for value, value_index in values {
		if value_index > 0 { local_json_literal(&writer, ",") }
		local_json_literal(&writer, "{")
		local_json_string(&writer, column)
		local_json_literal(&writer, ":")
		local_json_string(&writer, value)
		local_json_literal(&writer, ",\"created_by\":")
		if len(created_by) > 0 { local_json_string(&writer, created_by) } else { local_json_literal(&writer, "null") }
		local_json_literal(&writer, "}")
	}
	local_json_literal(&writer, "]")
	if writer.overflow { return {}, false }
	return {method = .Post, table = table, body = string(body_buffer[:writer.length])}, true
}

diagnostics_delete_request :: proc(
	kind: Diagnostics_Value_Kind,
	value: string,
	query_buffer: []u8,
	allocator: runtime.Allocator,
) -> (Request_Plan, bool) {
	column := diagnostics_value_column(kind)
	table := diagnostics_value_table(kind)
	encoded := net.percent_encode(value, allocator)
	required_length := len(column)+4+len(encoded)
	if len(column) == 0 || len(table) == 0 || len(value) == 0 || required_length > len(query_buffer) {
		return {}, false
	}
	write_index := 0
	parts := [?]string{column, "=eq.", encoded}
	for part in parts {
		copy(query_buffer[write_index:], transmute([]u8)part)
		write_index += len(part)
	}
	return {method = .Delete, table = table, query = string(query_buffer[:write_index])}, true
}
