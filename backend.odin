package launcher

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:thread"

BACKEND_EVENT_MAX_BYTES :: 1 << 20

Agent_Backend :: struct {
	process:       os.Process,
	stdin_file:    ^os.File,
	stdout_file:   ^os.File,
	reader:        ^thread.Thread,
	path:          string,
	stderr_path:   string,
	started:       bool,
	running:       bool,
	accept_events: bool,
}

backend: Agent_Backend

backend_init :: proc() {
	backend = {}
}

backend_destroy :: proc(state: ^App_State) {
	backend_stop(state)
	delete(backend.path)
	backend = {}
}

backend_default_path :: proc(allocator := context.allocator) -> string {
	if value := os.get_env("HW_AGENT_BIN", allocator); len(value) > 0 {
		return value
	}
	executable, err := os.get_executable_path(allocator)
	if err != nil || len(executable) == 0 {return ""}
	defer delete(executable)
	build_directory := filepath.dir(executable)
	project_directory := filepath.dir(build_directory)
	path, join_error := filepath.join(
		{project_directory, "../hw_agent/build/hw_agent"},
		allocator,
	)
	if join_error != nil {return ""}
	return path
}

backend_cleanup :: proc() {
	backend.accept_events = false
	if backend.stdin_file != nil {
		_ = os.close(backend.stdin_file)
		backend.stdin_file = nil
	}
	if backend.started {
		_ = os.process_kill(backend.process)
		_, _ = os.process_wait(backend.process)
		backend.started = false
	}
	if backend.stdout_file != nil {
		_ = os.close(backend.stdout_file)
		backend.stdout_file = nil
	}
	if backend.reader != nil {
		thread.join(backend.reader)
		thread.destroy(backend.reader)
		backend.reader = nil
	}
	backend.running = false
	if len(backend.stderr_path) > 0 {
		_ = os.remove(backend.stderr_path)
		delete(backend.stderr_path)
	}
	delete(backend.path)
	backend.path = ""
}

backend_stop :: proc(state: ^App_State) {
	backend_cleanup()
	state.backend_status = .Stopped
}

backend_start :: proc(state: ^App_State) -> string {
	if backend.running {return ""}
	backend_cleanup()

	path := backend_default_path()
	if len(path) == 0 || !os.exists(path) {
		defer if len(path) > 0 {delete(path)}
		return "hw_agent was not found. Build ../hw_agent or set HW_AGENT_BIN."
	}

	stdin_read, stdin_write, stdin_error := os.pipe()
	if stdin_error != nil {
		defer delete(path)
		return "Could not create the backend input pipe."
	}
	stdout_read, stdout_write, stdout_error := os.pipe()
	if stdout_error != nil {
		_ = os.close(stdin_read)
		_ = os.close(stdin_write)
		defer delete(path)
		return "Could not create the backend output pipe."
	}

	temporary_directory := os.get_env("TMPDIR", context.temp_allocator)
	if len(temporary_directory) == 0 {temporary_directory = "/tmp"}
	stderr_path := fmt.aprintf(
		"%s/hw_launcher_backend_%d.log",
		strings.trim_right(temporary_directory, "/"),
		os.get_pid(),
		allocator = context.temp_allocator,
	)
	stderr_file, stderr_open_error := os.open(
		stderr_path,
		{.Read, .Write, .Create, .Trunc},
		os.perm(0o600),
	)
	owned_stderr_path := strings.clone(stderr_path)
	if stderr_open_error != nil {
		_ = os.close(stdin_read)
		_ = os.close(stdin_write)
		_ = os.close(stdout_read)
		_ = os.close(stdout_write)
		delete(owned_stderr_path)
		delete(path)
		free_all(context.temp_allocator)
		return "Could not create the backend diagnostic log."
	}

	model_argument := fmt.aprintf("-model=%s", state.model, allocator = context.temp_allocator)
	working_directory := os.get_env("HOME", context.temp_allocator)
	process, start_error := os.process_start(os.Process_Desc {
		command = []string{path, "-rpc", model_argument},
		stdin = stdin_read,
		stdout = stdout_write,
		stderr = stderr_file,
		working_dir = working_directory,
	})
	_ = os.close(stdin_read)
	_ = os.close(stdout_write)
	_ = os.close(stderr_file)
	free_all(context.temp_allocator)
	if start_error != nil {
		_ = os.close(stdin_write)
		_ = os.close(stdout_read)
		_ = os.remove(owned_stderr_path)
		delete(owned_stderr_path)
		delete(path)
		return fmt.tprintf("Could not start %s: %v", path, start_error)
	}

	backend.process = process
	backend.stdin_file = stdin_write
	backend.stdout_file = stdout_read
	backend.stderr_path = owned_stderr_path
	backend.path = path
	backend.started = true
	backend.running = true
	backend.accept_events = true
	backend.reader = thread.create(backend_reader_thread)
	if backend.reader == nil {
		backend_cleanup()
		return "Could not create the backend reader thread."
	}
	thread.start(backend.reader)
	state.backend_status = .Starting
	return ""
}

read_limited_file :: proc(path: string, limit: int, allocator := context.allocator) -> string {
	file, open_error := os.open(path, {.Read})
	if open_error != nil {return ""}
	defer os.close(file)
	data := make([dynamic]u8, 0, min(limit, 4096), allocator)
	defer delete(data)
	buffer: [4096]u8
	for len(data) < limit {
		count, read_error := os.read(file, buffer[:min(len(buffer), limit-len(data))])
		if count > 0 {append(&data, ..buffer[:count])}
		if read_error != nil || count <= 0 {break}
	}
	return string(transmute([]u8)data[:])
}

backend_reader_thread :: proc(_: ^thread.Thread) {
	context = runtime.default_context()
	pending := make([dynamic]u8, 0, 4096, context.allocator)
	defer delete(pending)
	buffer: [64 << 10]u8

	read_loop: for {
		count, read_error := os.read(backend.stdout_file, buffer[:])
		if count > 0 {
			for value, index in buffer[:count] {
				if value != '\n' {
					append(&pending, value)
					if len(pending) > BACKEND_EVENT_MAX_BYTES {
						backend_dispatch_local(
							"__exited",
							"Backend event exceeded the 1 MiB safety limit.",
						)
						_ = os.process_kill(backend.process)
						clear(&pending)
						break read_loop
					}
					continue
				}
				line := string(transmute([]u8)pending[:])
				clear(&pending)
				if len(strings.trim_space(line)) == 0 {continue}
				event, ok := backend_decode_event(line)
				if ok {
					backend_dispatch_event(event)
				} else {
					backend_dispatch_local("error", "Backend emitted malformed JSON.")
				}
			}
		}
		if read_error != nil || count <= 0 {break}
	}
	diagnostic_text := read_limited_file(backend.stderr_path, 64 << 10)
	defer delete(diagnostic_text)
	if diagnostic := strings.trim_space(diagnostic_text); len(diagnostic) > 0 {
		backend_dispatch_local("error", diagnostic)
	}
	backend_dispatch_local("__exited", "The backend process stopped unexpectedly.")
}

backend_dispatch_local :: proc(kind, value: string) {
	event := Backend_Event_Wire {
		type = strings.clone(kind),
		text = strings.clone(value),
	}
	backend_dispatch_event(event)
}

backend_dispatch_event :: proc(event: Backend_Event_Wire) {
	boxed := new(Backend_Event_Wire, context.allocator)
	boxed^ = event
	dispatch_async_f(&_dispatch_main_q, rawptr(boxed), backend_apply_event_c)
}

backend_apply_event_c :: proc "c" (raw_event: rawptr) {
	context = runtime.default_context()
	event := (^Backend_Event_Wire)(raw_event)
	if backend.accept_events {
		launcher_apply_backend_event(&launcher, event^)
		launcher_request_redraw()
		if event.type == "__exited" {backend.running = false}
	}
	backend_event_destroy(event)
}

backend_send :: proc(command, text: string) -> string {
	if !backend.running || backend.stdin_file == nil {return "The backend is not running."}
	frame, ok := backend_encode_command(command, text, context.temp_allocator)
	if !ok {return "Could not encode the backend command."}
	defer delete(frame)
	defer free_all(context.temp_allocator)

	payload := make([dynamic]u8, 0, len(frame)+1, context.temp_allocator)
	append(&payload, ..transmute([]u8)frame)
	append(&payload, '\n')
	written := 0
	for written < len(payload) {
		count, write_error := os.write(backend.stdin_file, payload[written:])
		if write_error != nil || count <= 0 {return "Could not write to the backend."}
		written += count
	}
	return ""
}

backend_submit :: proc(state: ^App_State) {
	prompt := launcher_take_input(state)
	if len(prompt) == 0 {return}
	defer delete(prompt)

	was_running := backend.running
	command := "prompt"
	if !was_running {
		if message := backend_start(state); len(message) > 0 {
			state.backend_status = .Failed
			transcript_append(&state.transcript, .Error, message)
			launcher_request_redraw()
			return
		}
	} else if state.backend_status == .Busy || state.backend_status == .Starting {
		command = "steer"
	}

	if message := backend_send(command, prompt); len(message) > 0 {
		transcript_append(&state.transcript, .Error, message)
	}
	launcher_request_redraw()
}

backend_abort :: proc(state: ^App_State) {
	if !backend.running {return}
	if message := backend_send("abort", ""); len(message) > 0 {
		transcript_append(&state.transcript, .Error, message)
	}
	launcher_request_redraw()
}
