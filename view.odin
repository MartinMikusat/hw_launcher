package launcher

import "core:fmt"
import "core:strings"
import MTL "vendor:darwin/Metal"
import delta_settings "delta_support:settings"
import delta_ui "delta_support:ui"
import text_input "components:text_input"
import hw_clay "hw_clay:."
import hw_clay_ui "hw_clay:ui_framework"
import coretext "ui_framework:coretext"
import draw "ui_framework:draw"
import metal "ui_framework:metal"

LAUNCHER_WIDTH :: f32(760)
LAUNCHER_HEIGHT :: f32(520)
LAUNCHER_FONT_PIXELS :: 13
LAUNCHER_SCROLL_FOLLOW_DELTA :: f32(1 << 20)

Custom_Render_Kind :: enum {Input}

Launcher_Custom_Render :: struct {
	kind:     Custom_Render_Kind,
	input:    ^text_input.State,
	text:     string,
	placeholder: string,
}

Launcher_View :: struct {
	gpu:        metal.Renderer,
	text:       coretext.Context,
	list:       draw.List,
	renderer:   hw_clay_ui.Renderer,
	clay:       hw_clay.Context,
	memory:     []u8,
	style:      delta_ui.Style,
	theme:      delta_settings.Theme,
	theme_follows_system: bool,
	width:      f32,
	height:     f32,
	gpu_ready:  bool,
	initialized: bool,
	caret_visible: bool,
}

launcher_view: Launcher_View
launcher: App_State

view_init :: proc(device: rawptr) -> bool {
	if launcher_view.initialized {return true}
	launcher_view.width = LAUNCHER_WIDTH
	launcher_view.height = LAUNCHER_HEIGHT
	launcher_view.theme = .Light
	launcher_view.theme_follows_system = true
	launcher_view.caret_visible = true
	coretext.context_init(&launcher_view.text)
	draw.list_init(&launcher_view.list, pixel_ratio = 2)
	launcher_view.renderer = {
		list = &launcher_view.list,
		text = &launcher_view.text,
		viewport_height = LAUNCHER_HEIGHT,
	}
	delta_ui.initialize(
		&launcher_view.style,
		&launcher_view.renderer,
		LAUNCHER_FONT_PIXELS,
		launcher_view.theme,
	)
	launcher_view.memory = make([]u8, hw_clay.min_memory_size())
	if !hw_clay.initialize(
		&launcher_view.clay,
		launcher_view.memory,
		{LAUNCHER_WIDTH, LAUNCHER_HEIGHT},
	) {
		delete(launcher_view.memory)
		draw.list_destroy(&launcher_view.list)
		coretext.context_destroy(&launcher_view.text)
		launcher_view = {}
		return false
	}
	hw_clay.set_measure_text_function(
		&launcher_view.clay,
		hw_clay_ui.measure_text,
		&launcher_view.renderer,
	)
	if device != nil {
		if !metal.renderer_init(
			&launcher_view.gpu,
			device,
			"",
			uint(MTL.PixelFormat.BGRA8Unorm),
			true,
		) {
			delete(launcher_view.memory)
			draw.list_destroy(&launcher_view.list)
			coretext.context_destroy(&launcher_view.text)
			launcher_view = {}
			return false
		}
		launcher_view.gpu_ready = true
	}
	launcher_view.initialized = true
	return true
}

view_destroy :: proc() {
	if !launcher_view.initialized {return}
	if launcher_view.gpu_ready {metal.renderer_destroy(&launcher_view.gpu)}
	coretext.context_destroy(&launcher_view.text)
	draw.list_destroy(&launcher_view.list)
	delete(launcher_view.memory)
	launcher_view = {}
}

view_system_is_dark :: proc() -> bool {
	app := msg_id0(objc_getClass("NSApplication"), sel_registerName("sharedApplication"))
	if app == nil {return true}
	appearance := msg_id0(app, sel_registerName("effectiveAppearance"))
	if appearance == nil {return true}
	name := nsstring_to_string(msg_id0(appearance, sel_registerName("name")))
	return strings.contains(name, "Dark")
}

view_update_style :: proc() {
	theme := launcher_view.theme
	if launcher_view.theme_follows_system {
		theme = view_system_is_dark() ? .Dark : .Light
	}
	delta_ui.update(
		&launcher_view.style,
		&launcher_view.renderer,
		LAUNCHER_FONT_PIXELS,
		theme,
	)
}

view_push_text :: proc(
	ctx: ^hw_clay.Context,
	value: string,
	color := delta_ui.COLOR_CLEAR,
) {
	delta_ui.wrapped_text(&launcher_view.style, ctx, value, color)
}

view_push_user :: proc(ctx: ^hw_clay.Context, value: string) {
	hw_clay.open_element(ctx)
	hw_clay.configure_element(ctx, {
		layout = {
			sizing = {hw_clay.grow(), hw_clay.fit()},
			layout_direction = .Left_To_Right,
			child_alignment = {y = .Top},
		},
	})
	delta_ui.text(&launcher_view.style, ctx, ">")
	hw_clay.open_element(ctx)
	hw_clay.configure_element(ctx, {layout = {sizing = {hw_clay.grow(), hw_clay.fit()}}})
	delta_ui.wrapped_text(&launcher_view.style, ctx, value)
	hw_clay.pop_element(ctx)
	hw_clay.pop_element(ctx)
}

view_push_tool :: proc(ctx: ^hw_clay.Context, entry: Transcript_Entry) {
	hw_clay.open_element(ctx)
	hw_clay.configure_element(ctx, {
		layout = {
			sizing = {hw_clay.grow(), hw_clay.fixed(launcher_view.style.row_height)},
			child_alignment = {y = .Center},
		},
		clip = {horizontal = true},
	})
	delta_ui.text(&launcher_view.style, ctx, fmt.tprintf("$ %s ", entry.tool_name))
	hw_clay.open_element(ctx)
	hw_clay.configure_element(ctx, {layout = {sizing = {hw_clay.grow(), hw_clay.grow()}}, clip = {horizontal = true}})
	delta_ui.text(&launcher_view.style, ctx, entry.text)
	hw_clay.pop_element(ctx)
	state_label, state_color := "working", launcher_view.style.session_warning
	if !entry.tool_running {
		state_label = "error" if entry.tool_error else "ok"
		state_color = launcher_view.style.danger if entry.tool_error else delta_ui.COLOR_ONLINE
	}
	delta_ui.text(&launcher_view.style, ctx, fmt.tprintf(" [%s]", state_label), state_color)
	hw_clay.pop_element(ctx)
}

view_push_entry :: proc(ctx: ^hw_clay.Context, entry: Transcript_Entry, index: int) {
	hw_clay.open_element(ctx, hw_clay.id_indexed("launcher-entry", u32(index)))
	hw_clay.configure_element(ctx, {
		layout = {sizing = {hw_clay.grow(), hw_clay.fit()}},
	})
	switch entry.kind {
	case .User:
		view_push_user(ctx, entry.text)
	case .Assistant:
		view_push_text(ctx, entry.text)
	case .Tool:
		view_push_tool(ctx, entry)
	case .Error:
		view_push_text(ctx, entry.text, launcher_view.style.danger)
	case .Notice:
		view_push_text(ctx, entry.text, launcher_view.style.copy_text)
	}
	hw_clay.pop_element(ctx)
}

view_push_abort :: proc(ctx: ^hw_clay.Context) {
	if launcher.backend_status != .Busy && launcher.backend_status != .Starting {return}
	id := hw_clay.id("launcher-abort")
	hovered := hw_clay.pointer_over(ctx, id)
	hw_clay.open_element(ctx, id)
	hw_clay.configure_element(ctx, {
		layout = {sizing = {hw_clay.fit(), hw_clay.grow()}},
		background_color = hovered ? launcher_view.style.foreground : delta_ui.COLOR_CLEAR,
	})
	delta_ui.text(
		&launcher_view.style,
		ctx,
		"[Abort]",
		hovered ? launcher_view.style.background : launcher_view.style.foreground,
	)
	hw_clay.pop_element(ctx)
}

view_push_status :: proc(ctx: ^hw_clay.Context) {
	hw_clay.open_element(ctx, hw_clay.id("launcher-status"))
	hw_clay.configure_element(ctx, {
		layout = {
			sizing = {hw_clay.grow(), hw_clay.fixed(launcher_view.style.row_height)},
			child_alignment = {y = .Center},
		},
	})
	hw_clay.open_element(ctx)
	hw_clay.configure_element(ctx, {layout = {sizing = {hw_clay.grow(), hw_clay.grow()}}, clip = {horizontal = true}})
	delta_ui.text(
		&launcher_view.style,
		ctx,
		fmt.tprintf(
			"hw_launcher  %s  %s",
			launcher.model,
			launcher_status_text(launcher.backend_status),
		),
	)
	hw_clay.pop_element(ctx)
	view_push_abort(ctx)
	hw_clay.pop_element(ctx)
}

view_push_transcript :: proc(ctx: ^hw_clay.Context) {
	hw_clay.open_element(ctx, hw_clay.id("launcher-scroll"))
	hw_clay.configure_element(ctx, {
		layout = {
			sizing = {hw_clay.grow(), hw_clay.grow()},
			layout_direction = .Top_To_Bottom,
			padding = {top = u16(launcher_view.style.row_height)},
		},
		clip = {vertical = true, child_offset = hw_clay.get_scroll_offset(ctx)},
	})
	for &entry, index in launcher.transcript.entries {
		view_push_entry(ctx, entry, index)
	}
	hw_clay.pop_element(ctx)
}

view_push_input :: proc(ctx: ^hw_clay.Context) {
	custom := new(Launcher_Custom_Render, context.temp_allocator)
	custom^ = {
		kind = .Input,
		input = &launcher.input_state,
		text = launcher.input,
		placeholder = "Describe a task",
	}
	delta_ui.element(ctx, {
		layout = {sizing = {hw_clay.grow(), hw_clay.fixed(launcher_view.style.row_height)}},
		custom = {custom_data = custom},
	}, hw_clay.id("launcher-input"))
}

view_build_tree :: proc(ctx: ^hw_clay.Context) -> []hw_clay.Render_Command {
	hw_clay.begin_layout(ctx)
	hw_clay.open_element(ctx, hw_clay.id("launcher-root"))
	hw_clay.configure_element(ctx, {
		layout = {
			sizing = {hw_clay.grow(), hw_clay.grow()},
			layout_direction = .Top_To_Bottom,
			padding = hw_clay.padding_all(u16(launcher_view.style.ch)),
		},
		background_color = launcher_view.style.background,
	})
	view_push_status(ctx)
	view_push_transcript(ctx)
	view_push_input(ctx)
	hw_clay.pop_element(ctx)
	return hw_clay.end_layout(ctx, 1.0/60.0)
}

view_render_commands :: proc(commands: []hw_clay.Render_Command) {
	for command in commands {
		if command.command_type != .Custom {
			delta_ui.render_command(&launcher_view.style, &launcher_view.renderer, command)
			continue
		}
		custom := (^Launcher_Custom_Render)(command.render_data.(hw_clay.Custom_Render_Data).custom_data)
		assert(custom != nil && custom.kind == .Input)
		box := hw_clay_ui.rect_to_draw(&launcher_view.renderer, command.bounding_box)
		delta_ui.render_input(
			&launcher_view.style,
			&launcher_view.renderer,
			box,
			custom.text,
			custom.text,
			custom.placeholder,
			custom.input,
			true,
			launcher_view.caret_visible,
		)
	}
}

view_begin_frame :: proc(width, height: f32) -> []hw_clay.Render_Command {
	launcher_view.width = width
	launcher_view.height = height
	launcher_view.renderer.viewport_height = height
	view_update_style()
	hw_clay.set_layout_dimensions(&launcher_view.clay, {width, height})
	if launcher.follow_tail {
		hw_clay.update_scroll_containers(
			&launcher_view.clay,
			false,
			{0, LAUNCHER_SCROLL_FOLLOW_DELTA},
			1.0/60.0,
		)
		launcher.follow_tail = false
	}
	return view_build_tree(&launcher_view.clay)
}

view_input_box :: proc() -> (hw_clay.Bounding_Box, bool) {
	data := hw_clay.get_element_data(&launcher_view.clay, hw_clay.id("launcher-input"))
	return data.bounding_box, data.found
}

view_handle_click :: proc() -> bool {
	for id in hw_clay.get_pointer_over_ids(&launcher_view.clay) {
		if id == hw_clay.id("launcher-abort") {
			backend_abort(&launcher)
			return true
		}
	}
	return false
}

launcher_request_redraw :: proc() {
	// The host coalesces this request onto its display link.
	panel_mark_dirty()
}

view_test_initialize :: proc() -> bool {
	return view_init(nil)
}

view_test_destroy :: proc() {
	view_destroy()
}
