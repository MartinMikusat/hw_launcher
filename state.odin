package launcher

import "core:strings"
import text_input "components:text_input"

TRANSCRIPT_MAX_ENTRIES :: 500
ASSISTANT_TEXT_MAX_BYTES :: 1 << 20
TOOL_OUTPUT_MAX_BYTES :: 64 << 10

Backend_Status :: enum {
	Stopped,
	Starting,
	Ready,
	Busy,
	Failed,
}

Transcript_Kind :: enum {
	Notice,
	User,
	Assistant,
	Tool,
	Error,
}

Transcript_Entry :: struct {
	kind:        Transcript_Kind,
	text:        string,
	tool_id:     string,
	tool_name:   string,
	tool_running: bool,
	tool_error:  bool,
}

Transcript :: struct {
	entries:        [dynamic]Transcript_Entry,
	assistant_index: int,
}

App_State :: struct {
	backend_status: Backend_Status,
	model:          string,
	transcript:     Transcript,
	input:          string,
	input_state:    text_input.State,
	follow_tail:    bool,
}

launcher_state_init :: proc(state: ^App_State, allocator := context.allocator) {
	state^ = {}
	state.model = "anthropic/claude-haiku-4.5"
	state.transcript.entries = make([dynamic]Transcript_Entry, 0, 32, allocator)
	state.transcript.assistant_index = -1
	state.follow_tail = true
	transcript_append(&state.transcript, .Notice, "Ready at ~. Local tools run automatically.", allocator)
}

launcher_state_destroy :: proc(state: ^App_State) {
	transcript_destroy(&state.transcript)
	delete(state.input)
	text_input.destroy(&state.input_state)
	state^ = {}
}

transcript_destroy :: proc(transcript: ^Transcript) {
	for &entry in transcript.entries {
		delete(entry.text)
		delete(entry.tool_id)
		delete(entry.tool_name)
	}
	delete(transcript.entries)
	transcript^ = {}
}

transcript_replace_text :: proc(entry: ^Transcript_Entry, value: string) {
	delete(entry.text)
	entry.text = value
}

transcript_set_field :: proc(target: ^string, value: string, allocator := context.allocator) {
	replacement := strings.clone(value, allocator)
	delete(target^)
	target^ = replacement
}

transcript_prune :: proc(transcript: ^Transcript) {
	for len(transcript.entries) > TRANSCRIPT_MAX_ENTRIES {
		entry := &transcript.entries[0]
		delete(entry.text)
		delete(entry.tool_id)
		delete(entry.tool_name)
		ordered_remove(&transcript.entries, 0)
		if transcript.assistant_index >= 0 {transcript.assistant_index -= 1}
	}
}

transcript_append :: proc(
	transcript: ^Transcript,
	kind: Transcript_Kind,
	value: string,
	allocator := context.allocator,
) -> int {
	append(&transcript.entries, Transcript_Entry {
		kind = kind,
		text = strings.clone(value, allocator),
	})
	transcript_prune(transcript)
	return len(transcript.entries) - 1
}

transcript_begin_assistant :: proc(transcript: ^Transcript, allocator := context.allocator) {
	transcript.assistant_index = transcript_append(transcript, .Assistant, "", allocator)
}

transcript_update_assistant :: proc(
	transcript: ^Transcript,
	value: string,
	allocator := context.allocator,
) {
	if transcript.assistant_index < 0 {
		transcript_begin_assistant(transcript, allocator)
	}
	entry := &transcript.entries[transcript.assistant_index]
	transcript_replace_text(entry, bounded_text(value, ASSISTANT_TEXT_MAX_BYTES, allocator))
}

transcript_finish_assistant :: proc(
	transcript: ^Transcript,
	value: string,
	allocator := context.allocator,
) {
	transcript_update_assistant(transcript, value, allocator)
	transcript.assistant_index = -1
}

tool_entry_index :: proc(transcript: ^Transcript, id: string) -> int {
	for &entry, index in transcript.entries {
		if entry.kind == .Tool && entry.tool_id == id && entry.tool_running {
			return index
		}
	}
	return -1
}

transcript_tool_start :: proc(
	transcript: ^Transcript,
	id, name, arguments: string,
	allocator := context.allocator,
) {
	index := transcript_append(transcript, .Tool, arguments, allocator)
	entry := &transcript.entries[index]
	transcript_set_field(&entry.tool_id, id, allocator)
	transcript_set_field(&entry.tool_name, name, allocator)
	entry.tool_running = true
}

transcript_tool_end :: proc(
	transcript: ^Transcript,
	id, value: string,
	is_error: bool,
	allocator := context.allocator,
) {
	index := tool_entry_index(transcript, id)
	if index < 0 {
		index = transcript_append(transcript, .Tool, value, allocator)
		transcript.entries[index].tool_id = strings.clone(id, allocator)
	}
	entry := &transcript.entries[index]
	transcript_replace_text(entry, bounded_text(value, TOOL_OUTPUT_MAX_BYTES, allocator))
	entry.tool_running = false
	entry.tool_error = is_error
}

bounded_text :: proc(value: string, limit: int, allocator := context.allocator) -> string {
	if len(value) <= limit {return strings.clone(value, allocator)}
	cut := limit
	for cut > 0 && value[cut] & 0xC0 == 0x80 {cut -= 1}
	builder := strings.builder_make(allocator)
	strings.write_string(&builder, value[:cut])
	strings.write_string(&builder, "\n[truncated]")
	return strings.to_string(builder)
}

launcher_status_text :: proc(status: Backend_Status) -> string {
	switch status {
	case .Stopped: return "stopped"
	case .Starting: return "starting"
	case .Ready: return "ready"
	case .Busy: return "working"
	case .Failed: return "offline"
	}
	return "offline"
}
