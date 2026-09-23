package launcher

import "core:os"
import "core:strings"
import "core:testing"
import "core:thread"

@(test)
backend_diagnostics_and_repeated_cleanup_own_their_storage :: proc(t: ^testing.T) {
	file, err := os.create_temp_file("", "hw-launcher-test-*")
	if !testing.expect(t, err == nil) {return}
	path := strings.clone(os.name(file))
	defer delete(path)
	defer os.remove(path)
	_, _ = os.write_string(file, "diagnostic text")
	_ = os.close(file)
	value := read_limited_file(path, 10)
	defer delete(value)
	testing.expect_value(t, value, "diagnostic")
	backend_init()
	backend.stderr_path = strings.clone(path)
	backend.path = strings.clone("/missing/backend")
	backend_cleanup()
	testing.expect_value(t, backend.stderr_path, "")
	testing.expect_value(t, backend.path, "")
	backend_cleanup()
}

@(test)
backend_failed_start_keeps_path_in_error_and_can_retry :: proc(t: ^testing.T) {
	previous, had_previous := os.lookup_env("HW_AGENT_BIN", context.allocator)
	defer delete(previous)
	defer if had_previous {_ = os.set_env("HW_AGENT_BIN", previous)} else {_ = os.unset_env("HW_AGENT_BIN")}
	file, err := os.create_temp_file("", "hw-launcher-nonexecutable-*")
	if !testing.expect(t, err == nil) {return}
	path := strings.clone(os.name(file))
	defer delete(path)
	defer os.remove(path)
	_ = os.close(file)
	_ = os.set_env("HW_AGENT_BIN", path)
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)
	backend_init()
	defer backend_destroy(&state)
	for _ in 0..<2 {
		message := backend_start(&state)
		testing.expect(t, strings.has_prefix(message, "Could not start "), message)
		testing.expect(t, strings.contains(message, path), "failed start lost its path")
	}
}

@(test)
backend_closed_input_is_an_error_not_a_signal :: proc(t: ^testing.T) {
	read_end, write_end, err := os.pipe()
	if !testing.expect(t, err == nil) {return}
	defer os.close(write_end)
	if !testing.expect(t, backend_protect_pipe(write_end)) {os.close(read_end); return}
	_ = os.close(read_end)
	backend_init()
	backend.running = true
	backend.stdin_file = write_end
	defer backend = {}
	testing.expect_value(t, backend_send("prompt", "test"), "Could not write to the backend.")
}

@(test)
backend_shutdown_joins_reader_with_stdout_still_open :: proc(t: ^testing.T) {
	read_end, write_end, err := os.pipe()
	if !testing.expect(t, err == nil) {return}
	defer os.close(write_end)
	process, start_error := os.process_start({command = []string{"/bin/sleep", "30"}})
	if !testing.expect(t, start_error == nil) {os.close(read_end); return}
	backend_init()
	backend.process = process
	backend.started = true
	backend.running = true
	backend.stdout_file = read_end
	backend.reader = thread.create(backend_reader_thread)
	thread.start(backend.reader)
	launcher_state_init(&launcher)
	launcher_shutdown()
	testing.expect_value(t, backend.reader, nil)
	testing.expect_value(t, backend.stdout_file, nil)
	testing.expect(t, !backend.started && !backend.running)
	launcher_shutdown()
}

@(test)
backend_queued_events_are_freed_and_reject_old_sessions :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	backend_init()
	defer backend = {}
	backend_generation += 1
	backend.accept_events = true
	for generation in ([]u64{backend_generation-1, backend_generation}) {
		event, ok := backend_decode_event(`{"type":"error","text":"session error"}`)
		if !testing.expect(t, ok) {return}
		queued := new(Backend_Queued_Event)
		queued^ = {event, generation}
		backend_apply_queued_event(queued)
	}
	testing.expect_value(t, len(launcher.transcript.entries), 2)
	backend.accept_events = false
	event, _ := backend_decode_event(`{"type":"__exited","text":"stopped"}`)
	queued := new(Backend_Queued_Event)
	queued^ = {event, backend_generation}
	backend_apply_queued_event(queued)
	testing.expect_value(t, len(launcher.transcript.entries), 2)
}

@(test)
offscreen_ppm_writer_releases_scratch_with_its_allocator :: proc(t: ^testing.T) {
	file, err := os.create_temp_file("", "hw-launcher-frame-*")
	if !testing.expect(t, err == nil) {return}
	path := strings.clone(os.name(file))
	defer delete(path)
	defer os.remove(path)
	_ = os.close(file)
	pixels := [8]u8{0, 0, 255, 255, 255, 0, 0, 255}
	if !testing.expect(t, write_ppm(path, pixels[:], 2, 1)) {return}
	data, read_error := os.read_entire_file(path, context.allocator)
	defer delete(data)
	testing.expect(t, read_error == nil)
	testing.expect_value(t, string(data), "P6\n2 1\n255\n\xff\x00\x00\x00\x00\xff")
}
