package launcher

import "base:runtime"
import delta_ui "delta_support:ui"
import text_input "components:text_input"
import coretext "ui_framework:coretext"

LAUNCHER_INPUT_FIELD :: text_input.Field_ID(1)
LAUNCHER_INPUT_MAX_BYTES :: 16 << 10

input_focused :: proc() -> bool {
	return launcher.input_state.active_field == LAUNCHER_INPUT_FIELD
}

input_reset_caret :: proc() {
	launcher_view.caret_visible = true
	panel_reset_caret()
}

input_focus :: proc() {
	_ = text_input.focus(&launcher.input_state, LAUNCHER_INPUT_FIELD, launcher.input)
	text_input.move_line_end(&launcher.input_state, launcher.input, false)
	panel_make_first_responder()
	input_reset_caret()
	panel_mark_dirty()
}

input_blur :: proc() -> bool {
	blurred := text_input.blur(&launcher.input_state, &launcher.input)
	if blurred {panel_mark_dirty()}
	return blurred
}

input_value_valid :: proc(value: string) -> bool {
	if len(value) == 0 {return true}
	for character in value {
		if character < 32 && character != '\t' {return false}
		if character >= 0xF700 && character <= 0xF8FF {return false}
	}
	start, end := text_input.selection_bounds(&launcher.input_state, launcher.input)
	replaced := launcher.input_state.has_marked_text ? len(launcher.input_state.marked_text) : end-start
	return len(launcher.input)-replaced+len(value) <= LAUNCHER_INPUT_MAX_BYTES
}

input_insert :: proc(value: string) {
	if !input_focused() || !input_value_valid(value) {return}
	_ = text_input.remove_marked_text(&launcher.input_state, &launcher.input)
	if text_input.insert_text(&launcher.input_state, &launcher.input, value) {
		input_reset_caret()
		panel_mark_dirty()
	}
	text_input.unmark_text(&launcher.input_state)
}

input_submit :: proc() {
	backend_submit(&launcher)
	input_reset_caret()
}

input_copy :: proc() -> bool {
	if !input_focused() {return false}
	selected := text_input.selected_text(&launcher.input_state, launcher.input)
	if len(selected) == 0 {return false}
	pasteboard := msg_id0(objc_getClass("NSPasteboard"), sel_registerName("generalPasteboard"))
	if pasteboard == nil {return false}
	_ = msg_id0(pasteboard, sel_registerName("clearContents"))
	return msg_bool_id_id(
		pasteboard,
		sel_registerName("setString:forType:"),
		nsstring(selected),
		nsstring("public.utf8-plain-text"),
	)
}

input_cut :: proc() {
	if !input_copy() {return}
	if text_input.remove_selection(&launcher.input_state, &launcher.input) {
		input_reset_caret()
		panel_mark_dirty()
	}
}

input_paste :: proc() {
	pasteboard := msg_id0(objc_getClass("NSPasteboard"), sel_registerName("generalPasteboard"))
	if pasteboard == nil {return}
	value := msg_id_id(
		pasteboard,
		sel_registerName("stringForType:"),
		nsstring("public.utf8-plain-text"),
	)
	input_insert(nsstring_to_string(value))
}

input_select_all :: proc() {
	if !input_focused() {return}
	text_input.set_selection(&launcher.input_state, launcher.input, 0, len(launcher.input))
	panel_mark_dirty()
}

input_command :: proc(selector: string) -> bool {
	switch selector {
	case "insertNewline:":
		input_submit()
	case "cancelOperation:":
		panel_window_hide()
	case "insertTab:":
		input_insert("\t")
	case "copy:":
		return input_copy()
	case "cut:":
		input_cut()
		return true
	case "paste:":
		input_paste()
		return true
	case "selectAll:":
		input_select_all()
		return true
	case:
		if !input_focused() {return false}
		if !delta_ui.edit_command(&launcher.input_state, &launcher.input, selector) {return false}
		input_reset_caret()
		panel_mark_dirty()
		return true
	}
	return true
}

input_offset_at_point :: proc(point: Point) -> int {
	if !input_focused() || len(launcher.input) == 0 {return 0}
	box, found := view_input_box()
	if !found {return 0}
	text_box := delta_ui.input_text_bounds(&launcher_view.style, box)
	run := coretext.shape(
		&launcher_view.text,
		delta_ui.FONT_MONO,
		launcher.input,
		f32(launcher_view.style.text_size),
		0,
		0,
		false,
	)
	if run == nil {return 0}
	utf16 := coretext.utf16_index_for_offset(
		run,
		f32(point.x)-text_box.x+f32(launcher.input_state.scroll_x),
		launcher_view.text.backing_scale,
	)
	return text_input.byte_offset_for_utf16_index(launcher.input, utf16)
}

input_pointer_begin :: proc(point: Point, clicks: uint) -> bool {
	box, found := view_input_box()
	text_box := delta_ui.input_text_bounds(&launcher_view.style, box)
	if !found ||
	   f32(point.x) < text_box.x || f32(point.x) >= text_box.x+text_box.width ||
	   f32(point.y) < text_box.y || f32(point.y) >= text_box.y+text_box.height {
		return false
	}
	offset := input_offset_at_point(point)
	text_input.begin_pointer_selection(
		&launcher.input_state,
		LAUNCHER_INPUT_FIELD,
		launcher.input,
		offset,
		clicks,
	)
	input_focus()
	return true
}

input_pointer_update :: proc(point: Point) -> bool {
	if !input_focused() || !launcher.input_state.drag_active {return false}
	offset := input_offset_at_point(point)
	if !text_input.update_pointer_selection(
		&launcher.input_state,
		LAUNCHER_INPUT_FIELD,
		launcher.input,
		offset,
	) {return false}
	input_reset_caret()
	panel_mark_dirty()
	return true
}

input_native_text :: proc(value: Id) -> string {
	if value == nil {return ""}
	return nsstring_to_string(value)
}

launcher_on_text_insert :: proc "c" (
	self: Id,
	command: Sel,
	value: Id,
	replacement: ns_range,
) -> bool {
	context = runtime.default_context()
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	input_insert(input_native_text(value))
	return true
}

launcher_on_text_set_marked :: proc "c" (
	self: Id,
	command: Sel,
	value: Id,
	selected, replacement: ns_range,
) {
	context = runtime.default_context()
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	text := input_native_text(value)
	if !input_value_valid(text) {return}
	_ = text_input.remove_marked_text(&launcher.input_state, &launcher.input)
	_ = text_input.set_marked_text(
		&launcher.input_state,
		&launcher.input,
		text,
		int(selected.location),
		int(selected.length),
	)
	input_reset_caret()
	panel_mark_dirty()
}

launcher_on_text_unmark :: proc "c" (self: Id, command: Sel) {
	context = runtime.default_context()
	text_input.unmark_text(&launcher.input_state)
	input_reset_caret()
	panel_mark_dirty()
}

launcher_on_text_has_marked :: proc "c" (self: Id, command: Sel) -> bool {
	context = runtime.default_context()
	return launcher.input_state.has_marked_text
}

input_ns_range :: proc(value: text_input.UTF16_Range) -> ns_range {
	if !value.valid {return {~uint(0), 0}}
	return {uint(value.location), uint(value.length)}
}

launcher_on_text_range :: proc "c" (self: Id, command: Sel) -> ns_range {
	context = runtime.default_context()
	if !input_focused() {return {~uint(0), 0}}
	if command == sel_registerName("markedRange") {
		return input_ns_range(text_input.marked_utf16_range(&launcher.input_state, launcher.input))
	}
	return input_ns_range(text_input.selected_utf16_range(&launcher.input_state, launcher.input))
}

launcher_on_text_valid_attributes :: proc "c" (self: Id, command: Sel) -> Id {
	context = runtime.default_context()
	return msg_id0(objc_getClass("NSArray"), sel_registerName("array"))
}

launcher_on_text_substring :: proc "c" (
	self: Id,
	command: Sel,
	range: ns_range,
	actual: ^ns_range,
) -> Id {
	context = runtime.default_context()
	return nil
}

launcher_on_text_character_index :: proc "c" (self: Id, command: Sel, point: Point) -> uint {
	context = runtime.default_context()
	offset := input_offset_at_point(point)
	return uint(text_input.utf16_index_for_byte_offset(launcher.input, offset))
}

launcher_on_text_first_rect :: proc "c" (
	self: Id,
	command: Sel,
	range: ns_range,
	actual: ^ns_range,
) -> Rect {
	context = runtime.default_context()
	box, found := view_input_box()
	if !found {return {}}
	text_box := delta_ui.input_text_bounds(&launcher_view.style, box)
	input_rect := Rect{{f64(text_box.x), f64(text_box.y)}, {f64(text_box.width), f64(text_box.height)}}
	window_box := msg_rect_rect_id(
		panel_window.view,
		sel_registerName("convertRect:toView:"),
		input_rect,
		nil,
	)
	return msg_rect_rect(panel_window.window, sel_registerName("convertRectToScreen:"), window_box)
}

launcher_on_text_command :: proc "c" (self: Id, command: Sel, selector: Sel) {
	context = runtime.default_context()
	_ = input_command(nsstring_to_string(selector))
}

input_interpret_event :: proc(event: Id) {
	array := msg_id_id(objc_getClass("NSArray"), sel_registerName("arrayWithObject:"), event)
	msg_void_id(panel_window.view, sel_registerName("interpretKeyEvents:"), array)
}

input_register_methods :: proc(class: Id) -> bool {
	if protocol := objc_getProtocol("NSTextInputClient"); protocol != nil {
		_ = class_addProtocol(class, protocol)
	}
	return class_addMethod(class, sel_registerName("insertText:replacementRange:"), rawptr(launcher_on_text_insert), "B@:@{_NSRange=QQ}") &&
		class_addMethod(class, sel_registerName("setMarkedText:selectedRange:replacementRange:"), rawptr(launcher_on_text_set_marked), "v@:@{_NSRange=QQ}{_NSRange=QQ}") &&
		class_addMethod(class, sel_registerName("doCommandBySelector:"), rawptr(launcher_on_text_command), "v@::") &&
		class_addMethod(class, sel_registerName("unmarkText"), rawptr(launcher_on_text_unmark), "v@:") &&
		class_addMethod(class, sel_registerName("hasMarkedText"), rawptr(launcher_on_text_has_marked), "B@:") &&
		class_addMethod(class, sel_registerName("selectedRange"), rawptr(launcher_on_text_range), "{_NSRange=QQ}@:") &&
		class_addMethod(class, sel_registerName("markedRange"), rawptr(launcher_on_text_range), "{_NSRange=QQ}@:") &&
		class_addMethod(class, sel_registerName("validAttributesForMarkedText"), rawptr(launcher_on_text_valid_attributes), "@@:") &&
		class_addMethod(class, sel_registerName("attributedSubstringForProposedRange:actualRange:"), rawptr(launcher_on_text_substring), "@@:{_NSRange=QQ}^{_NSRange=QQ}") &&
		class_addMethod(class, sel_registerName("characterIndexForPoint:"), rawptr(launcher_on_text_character_index), "Q@:{CGPoint=dd}") &&
		class_addMethod(class, sel_registerName("firstRectForCharacterRange:actualRange:"), rawptr(launcher_on_text_first_rect), "{CGRect={CGPoint=dd}{CGSize=dd}}@:{_NSRange=QQ}^{_NSRange=QQ}")
}
