package settings

import "core:os"
import "core:fmt"
import "core:path/filepath"
import "base:runtime"

DEFAULT_SETTINGS_MAX_BYTES :: 1024 * 1024

Storage_Status :: enum {
	ok,
	not_found,
	too_large,
	read_failed,
	directory_failed,
	write_failed,
}

Storage_Read_Result :: struct {
	data: []u8,
	status: Storage_Status,
}

storage_read_json :: proc(
	path: string,
	allocator: runtime.Allocator,
	max_bytes: int = DEFAULT_SETTINGS_MAX_BYTES,
) -> Storage_Read_Result {
	assert(max_bytes > 0 && max_bytes < max(int))
	file, open_error := os.open(path)
	if open_error != nil {
		return {status = open_error == .Not_Exist ? .not_found : .read_failed}
	}
	defer os.close(file)
	// The extra byte detects overflow even if the file grows while being read.
	data := make([]u8, max_bytes + 1, allocator) or_else nil
	if len(data) != max_bytes + 1 {return {status = .read_failed}}
	count, read_error := os.read_full(file, data)
	if read_error != nil && read_error != .EOF {delete(data, allocator); return {status = .read_failed}}
	if count > max_bytes {delete(data, allocator); return {status = .too_large}}
	if count == 0 {delete(data, allocator); return {status = .ok}}
	return {data = data[:count], status = .ok}
}

storage_write_json :: proc(parent_directory, path: string, json: string) -> Storage_Status {
	if parent_directory != "" {
		directory_error := os.make_directory_all(parent_directory)
		if directory_error != nil && directory_error != .Exist {
			return .directory_failed
		}
	}
	if write_error := os.write_entire_file(path, json); write_error != nil {
		return .write_failed
	}
	return .ok
}

// One owner writes a settings path at a time. A failed write leaves the prior
// file intact; callers report failure without replacing their active values.
storage_write_json_atomic :: proc(path, content: string) -> bool {
	if path == "" {return false}
	temporary := fmt.tprintf("%s.tmp", path)
	defer os.remove(temporary)
	return storage_write_json(filepath.dir(path), temporary, content) == .ok && os.rename(temporary, path) == nil
}
