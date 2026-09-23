package launcher

import "core:strings"
import "core:testing"

@(test)
backend_command_escapes_prompt :: proc(t: ^testing.T) {
	encoded, ok := backend_encode_command("prompt", "say \"ok\"\n", context.allocator)
	defer delete(encoded)
	testing.expect(t, ok, "command encode failed")
	testing.expect(t, strings.contains(encoded, "\\\"ok\\\""), "quote was not escaped")
	testing.expect(t, strings.contains(encoded, "\\n"), "newline was not escaped")
	testing.expect(t, strings.has_prefix(encoded, "{"), "command is not a JSON object")
}

@(test)
backend_event_decodes_streaming_fields :: proc(t: ^testing.T) {
	event, ok := backend_decode_event(`{"type":"message_update","role":"Assistant","text":"partial"}`)
	defer backend_event_destroy(&event)
	testing.expect(t, ok, "event decode failed")
	testing.expect_value(t, event.type, "message_update")
	testing.expect_value(t, event.role, "Assistant")
	testing.expect_value(t, event.text, "partial")
}

@(test)
transcript_tracks_assistant_and_tool :: proc(t: ^testing.T) {
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)

	state.input = strings.clone("run the task")
	prompt := launcher_take_input(&state)
	defer delete(prompt)

	launcher_apply_backend_event(&state, Backend_Event_Wire{type = "message_start", role = "Assistant"})
	launcher_apply_backend_event(&state, Backend_Event_Wire{
		type = "message_update", role = "Assistant",
		text = "working",
	})
	launcher_apply_backend_event(&state, Backend_Event_Wire{
		type = "message_end", role = "Assistant",
		text = "done",
	})
	launcher_apply_backend_event(&state, Backend_Event_Wire{
		type = "tool_start",
		id = "call-1",
		name = "bash",
		arguments = "printf ok",
	})
	launcher_apply_backend_event(&state, Backend_Event_Wire{
		type = "tool_end",
		id = "call-1",
		text = "ok",
	})

	entries := state.transcript.entries
	testing.expect_value(t, entries[1].kind, Transcript_Kind.User)
	testing.expect_value(t, entries[1].text, "run the task")
	testing.expect_value(t, entries[2].kind, Transcript_Kind.Assistant)
	testing.expect_value(t, entries[2].text, "done")
	testing.expect_value(t, entries[3].kind, Transcript_Kind.Tool)
	testing.expect_value(t, entries[3].tool_running, false)
	testing.expect_value(t, entries[3].text, "ok")
}

@(test)
transcript_has_a_hard_entry_bound :: proc(t: ^testing.T) {
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)

	for index in 0 ..< TRANSCRIPT_MAX_ENTRIES+25 {
		transcript_append(&state.transcript, .Notice, "line")
		testing.expect_value(t, len(state.transcript.entries), min(index+2, TRANSCRIPT_MAX_ENTRIES))
	}
	testing.expect_value(t, len(state.transcript.entries), TRANSCRIPT_MAX_ENTRIES)
}

@(test)
backend_protocol_failure_retry_preserves_transcript_roles :: proc(t: ^testing.T) {
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)
	state.input = strings.clone("first prompt")
	prompt := launcher_take_input(&state)
	delete(prompt)
	for line in ([]string{
		`{"type":"ready"}`,
		`{"type":"agent_start"}`,
		`{"type":"message_start","role":"User"}`,
		`{"type":"message_end","role":"User","text":"first prompt"}`,
		`{"type":"message_start","role":"Assistant"}`,
		`{"type":"message_update","role":"Assistant","text":"partial reply"}`,
		`{"type":"message_start","role":"User"}`,
		`{"type":"message_end","role":"User","text":"steering echo"}`,
		`{"type":"tool_start","id":"call-1","name":"bash","arguments":"sleep 10"}`,
		`{"type":"__exited","text":"backend stopped"}`,
	}) {
		event, ok := backend_decode_event(line)
		if !testing.expect(t, ok) {return}
		launcher_apply_backend_event(&state, event)
		backend_event_destroy(&event)
	}
	testing.expect_value(t, len(state.transcript.entries), 5)
	testing.expect_value(t, state.transcript.entries[2].text, "partial reply")
	testing.expect_value(t, state.transcript.assistant_index, -1)
	testing.expect(t, !state.transcript.entries[3].tool_running && state.transcript.entries[3].tool_error)
	launcher_apply_backend_event(&state, {type = "ready"})
	launcher_apply_backend_event(&state, {type = "message_update", role = "Assistant", text = "new reply"})
	launcher_apply_backend_event(&state, {type = "message_end", role = "Assistant", text = "finished"})
	testing.expect_value(t, state.transcript.entries[2].text, "partial reply")
	testing.expect_value(t, state.transcript.entries[5].text, "finished")
	testing.expect_value(t, state.transcript.assistant_index, -1)
}

@(test)
offscreen_fixture_releases_owned_input :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	offscreen_fixture()
	testing.expect(t, len(launcher.input) > 0)
	launcher_state_destroy(&launcher)
}
