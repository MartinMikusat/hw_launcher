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
		"setAccessibilityValue:",
		"setAccessibilityFrame:",
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

	testing.expect(t, len(value) <= ACCESSIBILITY_TRANSCRIPT_MAX_BYTES+512, "accessible transcript exceeded its bound")
	testing.expect(t, strings.contains(value, "Earlier transcript omitted."), "truncation was not announced")
}

@(test)
accessibility_status_names_model_and_state :: proc(t: ^testing.T) {
	value := fmt_status("test/model", "ready")
	defer delete(value)
	testing.expect(t, strings.contains(value, "test/model"), "model missing from status")
	testing.expect(t, strings.contains(value, "ready"), "state missing from status")
}
