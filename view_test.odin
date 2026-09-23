package launcher

import "core:testing"
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
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_start"})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_update", text = "Reading the project files."})
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
