package settings

import "core:fmt"
import "core:os"
import "core:testing"
import "core:time"

@(test)
bounded_reads_and_atomic_settings_replacement :: proc(t: ^testing.T) {
	root := fmt.tprintf("%s/delta-settings-%d", os.temp_dir(context.temp_allocator), time.to_unix_nanoseconds(time.now()))
	defer os.remove_all(root)
	path := fmt.tprintf("%s/settings.json", root)
	testing.expect_value(t, storage_read_json(path, context.allocator, 4).status, Storage_Status.not_found)
	testing.expect(t, storage_write_json_atomic(path, "12345"))
	testing.expect_value(t, storage_read_json(path, context.allocator, 4).status, Storage_Status.too_large)
	read := storage_read_json(path, context.allocator, 5)
	testing.expect_value(t, read.status, Storage_Status.ok)
	testing.expect_value(t, string(read.data), "12345")
	delete(read.data)
	testing.expect(t, storage_write_json_atomic(path, "{}"))
	read = storage_read_json(path, context.allocator, 4096)
	testing.expect_value(t, read.status, Storage_Status.ok)
	testing.expect_value(t, string(read.data), "{}")
	delete(read.data)
	// Failed temporary creation must not truncate the existing settings.
	temporary := fmt.tprintf("%s.tmp", path)
	testing.expect(t, os.make_directory_all(temporary) == nil)
	testing.expect(t, !storage_write_json_atomic(path, "replacement"))
	read = storage_read_json(path, context.allocator, 4096)
	testing.expect_value(t, string(read.data), "{}")
	delete(read.data)
	testing.expect(t, storage_write_json_atomic(path, ""))
	read = storage_read_json(path, context.allocator, 4096)
	testing.expect(t, read.status == .ok && len(read.data) == 0)
	delete(read.data)
}
