package launcher

import "core:testing"
import "core:strings"
import text_input "components:text_input"
import hw_clay "hw_clay:."

@(test)
launcher_layout_has_fixed_status_and_input :: proc(t: ^testing.T) {
	launcher = {}
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	defer launcher_view = {}

	if !testing.expect(t, view_test_initialize(), "view initialization failed") {return}
	defer view_test_destroy()

	transcript_append(&launcher.transcript, .User, "Inspect the project")
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_start", role = "Assistant"})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_update", role = "Assistant", text = "Reading the project files."})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "tool_start",
		id = "tool-1",
		name = "read",
		arguments = "README.md",
	})
	_ = view_build_tree(&launcher_view.clay)

	status := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-status"))
	scroll := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-scroll"))
	input := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-input"))
	testing.expect(t, status.found && scroll.found && input.found, "launcher regions missing")
	testing.expect(t, status.bounding_box.y < scroll.bounding_box.y, "status must precede scrollback")
	testing.expect(t, scroll.bounding_box.y+scroll.bounding_box.height <= input.bounding_box.y, "scrollback overlaps input")
	testing.expect_value(t, input.bounding_box.height, launcher_view.style.row_height)
}

@(test)
launcher_scroll_follows_new_content_without_pointer_hover :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	if !testing.expect(t, view_test_initialize()) {return}
	defer view_test_destroy()
	launcher_view.theme_follows_system = false
	hw_clay.set_pointer_state(&launcher_view.clay, {-1, -1}, false)
	for _ in 0..<100 {transcript_append(&launcher.transcript, .Notice, "line")}
	_ = view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	scroll := hw_clay.get_scroll_container_data(&launcher_view.clay, hw_clay.id("launcher-scroll"))
	testing.expect(t, scroll.found)
	tail := -(scroll.content_dimensions.height-scroll.scroll_container_dimensions.height)
	testing.expect(t, tail < 0)
	testing.expect_value(t, scroll.scroll_position.y, tail)
	transcript_append(&launcher.transcript, .Notice, "newest line")
	launcher.follow_tail = true
	_ = view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	scroll = hw_clay.get_scroll_container_data(&launcher_view.clay, hw_clay.id("launcher-scroll"))
	testing.expect(t, scroll.scroll_position.y < tail)
	last := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id_indexed("launcher-entry", u32(len(launcher.transcript.entries)-1)))
	viewport := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-scroll"))
	testing.expect(t, last.bounding_box.y >= viewport.bounding_box.y)
	testing.expect(t, last.bounding_box.y+last.bounding_box.height <= viewport.bounding_box.y+viewport.bounding_box.height+0.01)
	// A manual scroll is retained until another event explicitly requests the tail.
	scroll.scroll_position.y = 0
	_ = view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	testing.expect_value(t, scroll.scroll_position.y, 0)
}

@(test)
launcher_input_pointer_and_ime_geometry_share_text_offsets :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	if !testing.expect(t, view_test_initialize()) {return}
	defer view_test_destroy()
	launcher_view.theme_follows_system = false
	launcher.input = strings.clone("hello world 🙂")
	input_focus()
	_ = view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	actual: ns_range
	first, found := input_character_rect({1, 0}, &actual)
	if !testing.expect(t, found) {return}
	testing.expect_value(t, actual, ns_range{1, 0})
	testing.expect_value(t, first.width, 0)
	point := Point{f64(first.x), f64(first.y+first.height/2)}
	testing.expect(t, input_pointer_begin(point, 2))
	testing.expect_value(t, text_input.selected_text(&launcher.input_state, launcher.input), "hello")
	testing.expect(t, launcher.input_state.drag_active)
	testing.expect(t, input_pointer_begin(point, 1))
	last, _ := input_character_rect({5, 0}, nil)
	testing.expect(t, input_pointer_update({f64(last.x), point.y}))
	testing.expect_value(t, text_input.selected_text(&launcher.input_state, launcher.input), "ello")
	text_input.end_pointer_selection(&launcher.input_state)
	word, _ := input_character_rect({0, 5}, nil)
	testing.expect(t, word.width > 0 && word.width < LAUNCHER_WIDTH/2)
	launcher.input_state.scroll_x = 10
	shifted, _ := input_character_rect({1, 0}, nil)
	testing.expect_value(t, shifted.x, first.x-10)
	visible_caret, _ := input_character_rect({3, 0}, nil)
	testing.expect_value(t, input_character_index_at_point({f64(visible_caret.x), point.y}), 3)
	testing.expect_value(t, input_character_index_at_point({-50, -50}), NS_NOT_FOUND)
	_, invalid := input_character_rect({13, 0}, &actual)
	testing.expect(t, !invalid, "mid-surrogate offset accepted")
	testing.expect_value(t, actual.location, NS_NOT_FOUND)
	native := panel_native_rect(word)
	testing.expect_value(t, native.origin.y, f64(LAUNCHER_HEIGHT-word.y-word.height))
	testing.expect(t, native.origin.y < 30, "input frame must be at the bottom of an unflipped view")
}

@(test)
launcher_abort_requires_press_and_release_inside :: proc(t: ^testing.T) {
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	if !testing.expect(t, view_test_initialize()) {return}
	defer view_test_destroy()
	launcher.backend_status = .Busy
	_ = view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	data := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-abort"))
	if !testing.expect(t, data.found) {return}
	point := hw_clay.Vector2{data.bounding_box.x+1, data.bounding_box.y+1}
	backend_init()
	backend.running = true // No stdin: an attempted Abort leaves a visible error.
	defer backend = {}
	panel_pointer_press({-1, -1}, 1)
	panel_pointer_release(point)
	testing.expect_value(t, len(launcher.transcript.entries), 1)
	panel_pointer_press(point, 1)
	panel_pointer_release({-1, -1})
	testing.expect_value(t, len(launcher.transcript.entries), 1)
	panel_pointer_press(point, 1)
	panel_pointer_release(point)
	testing.expect_value(t, len(launcher.transcript.entries), 2)
	testing.expect(t, !panel_window.abort_pressed)
}

@(test)
launcher_caret_rearms_and_hide_stops_scheduling :: proc(t: ^testing.T) {
	if !testing.expect(t, objc_initialize()) {return}
	pool := msg_id0(objc_getClass("NSAutoreleasePool"), sel_registerName("new"))
	defer msg_void0(pool, sel_registerName("drain"))
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	controller := panel_make_controller()
	if !testing.expect(t, controller != nil) {return}
	defer msg_void0(controller, sel_registerName("release"))
	panel_window.controller = controller
	panel_window.visible = true
	defer panel_window = {}
	launcher.input_state.active_field = LAUNCHER_INPUT_FIELD
	launcher_view.caret_visible = true
	panel_reset_caret()
	for index in 0..<3 {
		timer := panel_window.caret_timer
		if !testing.expect(t, timer != nil) {return}
		// Emulate the one-shot timer's invalidation, without pumping GUI events.
		msg_void0(timer, sel_registerName("invalidate"))
		panel_caret_blink(nil, nil, timer)
		testing.expect_value(t, launcher_view.caret_visible, index%2 == 1)
		testing.expect(t, panel_window.caret_timer != nil)
	}
	panel_window.frames_pending = 3
	panel_window_hide()
	testing.expect_value(t, panel_window.caret_timer, nil)
	testing.expect_value(t, panel_window.frames_pending, 0)
	panel_request_frames()
	testing.expect_value(t, panel_window.frames_pending, 0)
}
