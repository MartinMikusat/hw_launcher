package launcher

import "core:strings"
import "core:testing"

@(test)
accessibility_element_inherits_appkit_base :: proc(t: ^testing.T) {
	if !testing.expect(t, objc_initialize(), "Objective-C initialization failed") {return}
	if !testing.expect(t, accessibility_init(), "accessibility class registration failed") {return}
	class := objc_getClass("LauncherAccessibilityElement")
	superclass := class_getSuperclass(class)
	testing.expect_value(t, superclass, objc_getClass("NSAccessibilityElement"))

	element := msg_id0(class, sel_registerName("new"))
	defer msg_void0(element, sel_registerName("release"))
	for selector in ([]string{
		"setAccessibilityParent:",
		"setAccessibilityRole:",
		"setAccessibilityLabel:",
		"accessibilityValue",
		"setAccessibilityFrame:",
		"accessibilityPerformPress",
	}) {
		cselector := strings.clone_to_cstring(selector)
		supported := msg_bool_id(
			element,
			sel_registerName("respondsToSelector:"),
			rawptr(sel_registerName(cselector)),
		)
		delete(cselector)
		testing.expectf(
			t,
			supported,
			"accessibility element does not respond to %s",
			selector,
		)
	}
}

@(test)
accessibility_transcript_is_bounded :: proc(t: ^testing.T) {
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)

	large := strings.repeat("x", ACCESSIBILITY_TRANSCRIPT_MAX_BYTES*2)
	defer delete(large)
	transcript_append(&state.transcript, .Error, large)
	value := accessibility_transcript_text(&state)
	defer delete(value)

	testing.expect(t, len(value) <= ACCESSIBILITY_TRANSCRIPT_MAX_BYTES, "accessible transcript exceeded its bound")
	testing.expect(t, strings.contains(value, "Earlier transcript omitted."), "truncation was not announced")
}

@(test)
accessibility_status_names_model_and_state :: proc(t: ^testing.T) {
	value := fmt_status("test/model", "ready")
	defer delete(value)
	testing.expect(t, strings.contains(value, "test/model"), "model missing from status")
	testing.expect(t, strings.contains(value, "ready"), "state missing from status")
}

@(test)
accessibility_keeps_latest_text_and_independent_native_values :: proc(t: ^testing.T) {
	if !testing.expect(t, objc_initialize() && accessibility_init()) {return}
	pool := msg_id0(objc_getClass("NSAutoreleasePool"), sel_registerName("new"))
	defer msg_void0(pool, sel_registerName("drain"))
	state: App_State
	launcher_state_init(&state)
	defer launcher_state_destroy(&state)
	old := strings.repeat("🙂", 10000)
	defer delete(old)
	for _ in 0..<3 {transcript_append(&state.transcript, .Assistant, old)}
	transcript_append(&state.transcript, .Assistant, "latest response")
	value := accessibility_transcript_text(&state)
	defer delete(value)
	testing.expect(t, len(value) <= ACCESSIBILITY_TRANSCRIPT_MAX_BYTES)
	testing.expect(t, strings.has_prefix(value, "Earlier transcript omitted.\n"))
	testing.expect(t, strings.has_suffix(value, "Assistant: latest response\n"))
	for character in value {testing.expect(t, character != '\uFFFD', "truncation split UTF-8")}
	array := msg_id0(objc_getClass("NSMutableArray"), sel_registerName("array"))
	for role, index in ([3]string{"AXStaticText", "AXTextArea", "AXTextField"}) {
		expected := ([3]string{"ready", value, "draft prompt"})[index]
		accessibility_add_element(array, role, "label", expected, {})
		element := msg_id0(array, sel_registerName("lastObject"))
		testing.expect_value(t, nsstring_to_string(msg_id0(element, sel_registerName("accessibilityValue"))), expected)
	}
}
