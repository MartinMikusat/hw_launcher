package launcher

import "core:encoding/json"
import "core:strings"
import text_input "components:text_input"

Backend_Event_Wire :: struct {
	type:          string `json:"type"`,
	text:          string `json:"text"`,
	role:          string `json:"role"`,
	id:            string `json:"id"`,
	name:          string `json:"name"`,
	arguments:     string `json:"arguments"`,
	is_error:      bool   `json:"is_error"`,
	summary:       string `json:"summary"`,
	tokens_before: int    `json:"tokens_before"`,
}

Backend_Command :: struct {
	cmd:  string `json:"cmd"`,
	text: string `json:"text,omitempty"`,
}

backend_event_destroy :: proc(event: ^Backend_Event_Wire) {
	delete(event.type)
	delete(event.text)
	delete(event.role)
	delete(event.id)
	delete(event.name)
	delete(event.arguments)
	delete(event.summary)
	event^ = {}
}

backend_decode_event :: proc(line: string, allocator := context.allocator) -> (Backend_Event_Wire, bool) {
	event: Backend_Event_Wire
	if json.unmarshal(transmute([]u8)line, &event, .JSON, allocator) != nil {
		backend_event_destroy(&event)
		return {}, false
	}
	if len(event.type) == 0 {
		backend_event_destroy(&event)
		return {}, false
	}
	return event, true
}

backend_encode_command :: proc(
	command, text: string,
	allocator := context.allocator,
) -> (string, bool) {
	payload, err := json.marshal(
		Backend_Command{cmd = command, text = text},
		allocator = allocator,
	)
	if err != nil {return "", false}
	defer delete(payload)
	return strings.clone(string(payload), allocator), true
}

launcher_take_input :: proc(state: ^App_State, allocator := context.allocator) -> string {
	value := strings.trim_space(state.input)
	if len(value) == 0 {return ""}
	prompt := strings.clone(value, allocator)
	delete(state.input)
	state.input = ""
	text_input.set_selection(&state.input_state, state.input, 0, 0)
	transcript_append(&state.transcript, .User, prompt)
	state.follow_tail = true
	return prompt
}

launcher_apply_backend_event :: proc(state: ^App_State, event: Backend_Event_Wire) {
	switch event.type {
	case "ready":
		state.backend_status = .Ready
	case "agent_start":
		state.backend_status = .Busy
		state.follow_tail = true
	case "message_start":
		transcript_begin_assistant(&state.transcript)
		state.follow_tail = true
	case "message_update":
		transcript_update_assistant(&state.transcript, event.text)
		state.follow_tail = true
	case "message_end":
		transcript_finish_assistant(&state.transcript, event.text)
		state.follow_tail = true
	case "tool_start":
		transcript_tool_start(&state.transcript, event.id, event.name, event.arguments)
		state.follow_tail = true
	case "tool_end":
		transcript_tool_end(&state.transcript, event.id, event.text, event.is_error)
		state.follow_tail = true
	case "compaction":
		transcript_append(&state.transcript, .Notice, "Context compacted.")
		state.follow_tail = true
	case "error":
		transcript_append(&state.transcript, .Error, event.text)
		state.follow_tail = true
	case "__exited":
		state.backend_status = .Failed
		transcript_append(&state.transcript, .Error, event.text)
		state.follow_tail = true
	case:
		// Prompt, turn, and unknown control events carry no transcript state.
	}
}
