package launcher

import "base:runtime"
import "core:strings"
import text_input "components:text_input"
import hw_clay "hw_clay:."

ACCESSIBILITY_TRANSCRIPT_MAX_BYTES :: 64 << 10

accessibility_class: Id

accessibility_init :: proc() -> bool {
	class := objc_allocateClassPair(objc_getClass("NSObject"), "LauncherAccessibilityElement", 0)
	if class == nil {return false}
	if !panel_add_method(class, "accessibilityIsElement", rawptr(accessibility_is_element), "B@:") ||
	   !panel_add_method(class, "accessibilitySetValue:", rawptr(accessibility_set_value), "v@:@") ||
	   !panel_add_method(class, "accessibilityPerformPress:", rawptr(accessibility_press), "B@:@") {
		return false
	}
	objc_registerClassPair(class)
	accessibility_class = class
	return true
}

accessibility_is_element :: proc "c" (self: Id, command: Sel) -> bool {
	return true
}

accessibility_set_value :: proc "c" (self: Id, command: Sel, value: Id) {
	context = runtime.default_context()
	role := nsstring_to_string(msg_id0(self, sel_registerName("accessibilityRole")))
	if role != "AXTextField" {return}
	text := nsstring_to_string(value)
	delete(launcher.input)
	launcher.input = strings.clone(text)
	text_input.set_selection(&launcher.input_state, launcher.input, 0, len(launcher.input))
	input_reset_caret()
	panel_mark_dirty()
}

accessibility_press :: proc "c" (self: Id, command: Sel, sender: Id) -> bool {
	context = runtime.default_context()
	role := nsstring_to_string(msg_id0(self, sel_registerName("accessibilityRole")))
	if role != "AXButton" {return false}
	backend_abort(&launcher)
	return true
}

fmt_status :: proc(model, status: string, allocator := context.allocator) -> string {
	builder := strings.builder_make(allocator)
	strings.write_string(&builder, "hw_launcher, model ")
	strings.write_string(&builder, model)
	strings.write_string(&builder, ", ")
	strings.write_string(&builder, status)
	return strings.to_string(builder)
}

accessibility_transcript_text :: proc(
	state: ^App_State,
	allocator := context.allocator,
) -> string {
	builder := strings.builder_make(allocator)
	truncated := false
	for &entry in state.transcript.entries {
		remaining := ACCESSIBILITY_TRANSCRIPT_MAX_BYTES-strings.builder_len(builder)
		if remaining <= 32 {truncated = true; break}
		switch entry.kind {
		case .Notice:
			strings.write_string(&builder, "Status: ")
		case .User:
			strings.write_string(&builder, "You: ")
		case .Assistant:
			strings.write_string(&builder, "Assistant: ")
		case .Tool:
			strings.write_string(&builder, "Tool ")
			strings.write_string(&builder, entry.tool_name)
			strings.write_string(&builder, ": ")
		case .Error:
			strings.write_string(&builder, "Error: ")
		}
		value := bounded_text(
			entry.text,
			max(1, remaining-strings.builder_len(builder)),
			context.temp_allocator,
		)
		strings.write_string(&builder, value)
		strings.write_string(&builder, "\n")
		if len(value) < len(entry.text) {truncated = true; break}
	}
	if truncated {strings.write_string(&builder, "Earlier transcript omitted.\n")}
	strings.write_string(&builder, "Prompt: ")
	strings.write_string(&builder, state.input)
	return strings.to_string(builder)
}

accessibility_add_element :: proc(
	array: Id,
	role, label: string,
	value: string,
	rect: hw_clay.Bounding_Box,
) {
	element := msg_id0(accessibility_class, sel_registerName("alloc"))
	element = msg_id0(element, sel_registerName("init"))
	msg_void_id(element, sel_registerName("setAccessibilityParent:"), panel_window.view)
	msg_void_id(element, sel_registerName("setAccessibilityRole:"), nsstring(role))
	msg_void_id(element, sel_registerName("setAccessibilityLabel:"), nsstring(label))
	if len(value) > 0 {
		msg_void_id(element, sel_registerName("setAccessibilityValue:"), nsstring(value))
	}
	local := Rect{{f64(rect.x), f64(rect.y)}, {f64(rect.width), f64(rect.height)}}
	window_rect := msg_rect_rect_id(
		panel_window.view,
		sel_registerName("convertRect:toView:"),
		local,
		nil,
	)
	screen_rect := msg_rect_rect(
		panel_window.window,
		sel_registerName("convertRectToScreen:"),
		window_rect,
	)
	msg_void_rect(element, sel_registerName("setAccessibilityFrame:"), screen_rect)
	msg_void_id(array, sel_registerName("addObject:"), element)
	msg_void0(element, sel_registerName("release"))
}

accessibility_rebuild :: proc() {
	if panel_window.view == nil || panel_window.window == nil {return}
	array := msg_id0(objc_getClass("NSMutableArray"), sel_registerName("array"))
	status_box := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-status"))
	transcript_box := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-scroll"))
	input_box, input_found := view_input_box()
	if status_box.found {
		accessibility_add_element(
			array,
			"AXStaticText",
			"Launcher status",
			fmt_status(
				launcher.model,
				launcher_status_text(launcher.backend_status),
				context.temp_allocator,
			),
			status_box.bounding_box,
		)
	}
	if transcript_box.found {
		accessibility_add_element(
			array,
			"AXTextArea",
			"Agent transcript",
			accessibility_transcript_text(&launcher, context.temp_allocator),
			transcript_box.bounding_box,
		)
	}
	if input_found {
		accessibility_add_element(
			array,
			"AXTextField",
			"Task prompt",
			launcher.input,
			input_box,
		)
	}
	if launcher.backend_status == .Busy || launcher.backend_status == .Starting {
		abort_box := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-abort"))
		if abort_box.found {
			accessibility_add_element(array, "AXButton", "Abort agent", "", abort_box.bounding_box)
		}
	}
	msg_void_id(panel_window.view, sel_registerName("setAccessibilityChildren:"), array)
}
