package launcher

import "base:runtime"
import "core:strings"
import hw_clay "hw_clay:."

ACCESSIBILITY_TRANSCRIPT_MAX_BYTES :: 64 << 10

accessibility_class: Id

accessibility_init :: proc() -> bool {
	if accessibility_class != nil {return true}
	class := objc_allocateClassPair(
		objc_getClass("NSAccessibilityElement"),
		"LauncherAccessibilityElement",
		0,
	)
	if class == nil {return false}
	if !panel_add_method(class, "isAccessibilityElement", rawptr(accessibility_is_element), "B@:") ||
	   !panel_add_method(class, "accessibilityPerformPress", rawptr(accessibility_press), "B@:") {
		return false
	}
	objc_registerClassPair(class)
	accessibility_class = class
	return true
}

accessibility_is_element :: proc "c" (self: Id, command: Sel) -> bool {
	return true
}

accessibility_press :: proc "c" (self: Id, command: Sel) -> bool {
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
	// Stream the suffix of the logical transcript without allocating omitted text.
	prefixes := [Transcript_Kind]string{.Notice = "Status: ", .User = "You: ",
		.Assistant = "Assistant: ", .Tool = "Tool ", .Error = "Error: "}
	total := 0
	for &entry in state.transcript.entries {
		total += len(prefixes[entry.kind])+len(entry.text)+1
		if entry.kind == .Tool {total += len(entry.tool_name)+2}
	}
	marker :: "Earlier transcript omitted.\n"
	budget := ACCESSIBILITY_TRANSCRIPT_MAX_BYTES
	builder := strings.builder_make(allocator)
	if total > budget {
		strings.write_string(&builder, marker)
		budget -= len(marker)
	}
	skip := max(0, total-budget)
	for &entry in state.transcript.entries {
		parts := [5]string{prefixes[entry.kind], "", "", entry.text, "\n"}
		if entry.kind == .Tool {parts[1], parts[2] = entry.tool_name, ": "}
		for part in parts {
			if skip >= len(part) {skip -= len(part); continue}
			start := skip
			skip = 0
			for start < len(part) && part[start]&0xC0 == 0x80 {start += 1}
			strings.write_string(&builder, part[start:])
		}
	}
	// The prompt has its own AXTextField; do not duplicate it in scrollback.
	return strings.to_string(builder)
}

accessibility_add_element :: proc(
	array: Id,
	role, label: string,
	value: string,
	rect: hw_clay.Bounding_Box,
) {
	element := msg_id0(accessibility_class, sel_registerName("new"))
	msg_void_id(element, sel_registerName("setAccessibilityParent:"), panel_window.view)
	msg_void_id(element, sel_registerName("setAccessibilityRole:"), nsstring(role))
	msg_void_id(element, sel_registerName("setAccessibilityLabel:"), nsstring(label))
	msg_void_id(element, sel_registerName("setAccessibilityValue:"), nsstring(value))
	screen_rect := panel_rect_to_screen(rect)
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
			accessibility_add_element(array, "AXButton", "Abort agent (Command-period)", "", abort_box.bounding_box)
		}
	}
	msg_void_id(panel_window.view, sel_registerName("setAccessibilityChildren:"), array)
}
