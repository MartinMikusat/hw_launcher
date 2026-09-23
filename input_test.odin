package launcher

import "base:runtime"
import "core:strings"
import "core:testing"
import text_input "components:text_input"

@(test)
input_native_values_and_command_selector :: proc(t: ^testing.T) {
	if !testing.expect(t, objc_initialize()) {return}
	pool := msg_id0(objc_getClass("NSAutoreleasePool"), sel_registerName("new"))
	defer msg_void0(pool, sel_registerName("drain"))
	plain := nsstring("日本語 🙂")
	attributed := msg_id_id(msg_id0(objc_getClass("NSAttributedString"), sel_registerName("alloc")),
		sel_registerName("initWithString:"), plain)
	defer msg_void0(attributed, sel_registerName("release"))
	testing.expect_value(t, input_native_text(plain), "日本語 🙂")
	testing.expect_value(t, input_native_text(attributed), "日本語 🙂")
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	launcher.input = strings.clone("abc")
	input_focus()
	launcher_on_text_command(nil, nil, sel_registerName("moveLeft:"))
	testing.expect_value(t, launcher.input_state.caret_byte_offset, 2)
	launcher_on_text_command(nil, nil, sel_registerName("moveToBeginningOfLine:"))
	testing.expect_value(t, launcher.input_state.caret_byte_offset, 0)
	actual: ns_range
	substring := launcher_on_text_substring(nil, nil, {1, 2}, &actual)
	testing.expect_value(t, input_native_text(substring), "bc")
	testing.expect_value(t, actual, ns_range{1, 2})
}

@(test)
input_native_callbacks_honor_appkit_not_found_and_replacement :: proc(t: ^testing.T) {
	if !testing.expect(t, objc_initialize()) {return}
	// Native callbacks establish the runtime allocator. Keep their owned state on it.
	context.allocator = runtime.default_context().allocator
	pool := msg_id0(objc_getClass("NSAutoreleasePool"), sel_registerName("new"))
	defer msg_void0(pool, sel_registerName("drain"))
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	input_focus()
	launcher_on_text_insert(nil, nil, nsstring("a🙂b"), {NS_NOT_FOUND, 0})
	testing.expect_value(t, launcher.input, "a🙂b")
	value := msg_id_id(msg_id0(objc_getClass("NSAttributedString"), sel_registerName("alloc")),
		sel_registerName("initWithString:"), nsstring("日"))
	defer msg_void0(value, sel_registerName("release"))
	launcher_on_text_set_marked(nil, nil, value, {1, 0}, {1, 2})
	testing.expect_value(t, launcher.input, "a日b")
	launcher_on_text_insert(nil, nil, nsstring("語"), {NS_NOT_FOUND, 0})
	testing.expect_value(t, launcher.input, "a語b")
	testing.expect_value(t, launcher_on_text_range(nil, sel_registerName("markedRange")), ns_range{NS_NOT_FOUND, 0})
}

@(test)
input_replacement_and_composition_use_utf16_ranges :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	launcher.input = strings.clone("a🙂bc")
	input_focus()
	input_insert("Z", {1, 2})
	testing.expect_value(t, launcher.input, "aZbc")
	input_set_marked("日", {1, 0}, {1, 1})
	testing.expect_value(t, launcher.input, "a日bc")
	input_set_marked("日本", {2, 0}, {NS_NOT_FOUND, 0})
	testing.expect_value(t, launcher.input, "a日本bc")
	input_insert("語")
	testing.expect_value(t, launcher.input, "a語bc")
	testing.expect(t, !launcher.input_state.has_marked_text)
	// An explicit replacement wins even when another marked range is active.
	input_set_marked("🙂", {2, 0}, {1, 1})
	input_insert("A", {0, 1})
	testing.expect_value(t, launcher.input, "A🙂bc")
	for invalid in ([]ns_range{{2, 1}, {100, 0}, {1, ~uint(0)}}) {
		input_insert("bad", invalid)
		testing.expect_value(t, launcher.input, "A🙂bc")
	}
	input_insert("bad\n", {0, 0})
	testing.expect_value(t, launcher.input, "A🙂bc")
	large := strings.repeat("x", LAUNCHER_INPUT_MAX_BYTES)
	defer delete(large)
	input_insert(large, {0, 0})
	testing.expect_value(t, launcher.input, "A🙂bc")
	input_insert(large, {0, 5})
	testing.expect_value(t, len(launcher.input), LAUNCHER_INPUT_MAX_BYTES)
	input_insert("x")
	testing.expect_value(t, len(launcher.input), LAUNCHER_INPUT_MAX_BYTES)
	input_insert("", {0, LAUNCHER_INPUT_MAX_BYTES})
	testing.expect_value(t, launcher.input, "")
	input_set_marked("unfinished", {10, 0}, {NS_NOT_FOUND, 0})
	testing.expect(t, launcher.input_state.has_marked_text)
	prompt := launcher_take_input(&launcher)
	defer delete(prompt)
	testing.expect_value(t, prompt, "unfinished")
	testing.expect(t, !launcher.input_state.has_marked_text)
	// Destruction also owns any remaining composition buffer.
	input_set_marked("unfinished", {10, 0}, {NS_NOT_FOUND, 0})
}

@(test)
input_focus_preserves_existing_selection :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	launcher.input = strings.clone("hello world")
	input_focus()
	text_input.set_selection(&launcher.input_state, launcher.input, 0, 5)
	input_focus()
	testing.expect_value(t, text_input.selected_text(&launcher.input_state, launcher.input), "hello")
}
