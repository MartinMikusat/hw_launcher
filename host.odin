package launcher

import "base:runtime"
import "core:fmt"
import MTL "vendor:darwin/Metal"
import QC "vendor:darwin/QuartzCore"
import NS "core:sys/darwin/Foundation"
import text_input "components:text_input"
import hw_clay "hw_clay:."
import hw_clay_ui "hw_clay:ui_framework"
import coretext "ui_framework:coretext"
import draw "ui_framework:draw"
import macos "ui_framework:macos"
import metal "ui_framework:metal"

PANEL_WINDOW_LEVEL :: 25
PANEL_MARGIN :: 8.0
NSEVENT_MASK_LEFT_MOUSE_UP :: uint(1 << 2)

Panel_Host :: struct {
	app:          Id,
	status_item:  Id,
	status_button: Id,
	controller:   Id,
	delegate:     Id,
	window:       Id,
	view:         Id,
	layer:        ^QC.MetalLayer,
	device:       ^MTL.Device,
	queue:        ^MTL.CommandQueue,
	display_link: macos.Display_Link,
	caret_timer:  Id,
	visible:      bool,
	frames_pending: int,
	drawing:      bool,
	draw_scheduled: bool,
	pointer:      hw_clay.Vector2,
	pointer_valid: bool,
	pointer_down: bool,
	abort_pressed: bool,
	scroll_delta: hw_clay.Vector2,
}

panel_window: Panel_Host

panel_add_method :: proc(class: Id, name: cstring, imp: rawptr, types: cstring) -> bool {
	return class_addMethod(class, sel_registerName(name), imp, types)
}

panel_make_controller :: proc() -> Id {
	class := objc_allocateClassPair(objc_getClass("NSObject"), "LauncherController", 0)
	if class == nil {return nil}
	if !panel_add_method(class, "launcherFrame:", rawptr(panel_frame_callback), "v@:@") ||
	   !panel_add_method(class, "launcherToggle:", rawptr(panel_toggle_callback), "v@:@") ||
	   !panel_add_method(class, "launcherQuit:", rawptr(panel_quit_callback), "v@:@") ||
	   !panel_add_method(class, "launcherCaretBlink:", rawptr(panel_caret_blink), "v@:@") {
		return nil
	}
	objc_registerClassPair(class)
	controller := msg_id0(class, sel_registerName("alloc"))
	return msg_id0(controller, sel_registerName("init"))
}

panel_make_delegate :: proc() -> Id {
	class := objc_allocateClassPair(objc_getClass("NSObject"), "LauncherPanelDelegate", 0)
	if class == nil {return nil}
	if !panel_add_method(class, "windowDidResignKey:", rawptr(panel_did_resign_key), "v@:@") ||
	   !panel_add_method(class, "applicationWillTerminate:", rawptr(panel_will_terminate), "v@:@") {
		return nil
	}
	objc_registerClassPair(class)
	delegate := msg_id0(class, sel_registerName("alloc"))
	return msg_id0(delegate, sel_registerName("init"))
}

panel_make_view_class :: proc() -> Id {
	class := objc_allocateClassPair(objc_getClass("NSView"), "LauncherView", 0)
	if class == nil {return nil}
	if !panel_add_method(class, "acceptsFirstResponder", rawptr(panel_accepts_first_responder), "B@:") ||
	   !panel_add_method(class, "acceptsFirstMouse:", rawptr(panel_accepts_first_mouse), "B@:@") ||
	   !panel_add_method(class, "mouseDown:", rawptr(panel_mouse_down), "v@:@") ||
	   !panel_add_method(class, "mouseUp:", rawptr(panel_mouse_up), "v@:@") ||
	   !panel_add_method(class, "mouseDragged:", rawptr(panel_mouse_dragged), "v@:@") ||
	   !panel_add_method(class, "mouseMoved:", rawptr(panel_mouse_moved), "v@:@") ||
	   !panel_add_method(class, "scrollWheel:", rawptr(panel_scroll), "v@:@") ||
	   !panel_add_method(class, "keyDown:", rawptr(panel_key_down), "v@:@") ||
	   !input_register_methods(class) {
		return nil
	}
	objc_registerClassPair(class)
	return class
}

panel_make_window_class :: proc() -> Id {
	class := objc_allocateClassPair(objc_getClass("NSPanel"), "LauncherPanel", 0)
	if class == nil {return nil}
	if !panel_add_method(class, "canBecomeKeyWindow", rawptr(panel_can_become_key), "B@:") {
		return nil
	}
	objc_registerClassPair(class)
	return class
}

panel_init :: proc() -> bool {
	device := MTL.CreateSystemDefaultDevice()
	if device == nil {return false}
	queue := device->newCommandQueue()
	if queue == nil {return false}

	if !accessibility_init() {return false}
	controller := panel_make_controller()
	delegate := panel_make_delegate()
	view_class := panel_make_view_class()
	window_class := panel_make_window_class()
	if controller == nil || delegate == nil || view_class == nil || window_class == nil {return false}

	frame := Rect{{0, 0}, {f64(LAUNCHER_WIDTH), f64(LAUNCHER_HEIGHT)}}
	window := msg_id0(window_class, sel_registerName("alloc"))
	window = msg_id_rect_u_u_i(
		window,
		sel_registerName("initWithContentRect:styleMask:backing:defer:"),
		frame,
		uint(NS.WindowStyleMask{.NonactivatingPanel}),
		2,
		0,
	)
	if window == nil {return false}
	msg_void_bool(window, sel_registerName("setOpaque:"), true)
	msg_void_bool(window, sel_registerName("setAcceptsMouseMovedEvents:"), true)
	msg_void_bool(window, sel_registerName("setHasShadow:"), false)
	msg_void_bool(window, sel_registerName("setMovable:"), false)
	msg_void_bool(window, sel_registerName("setReleasedWhenClosed:"), false)
	msg_void_i(window, sel_registerName("setAnimationBehavior:"), 2)
	msg_void_i(window, sel_registerName("setLevel:"), PANEL_WINDOW_LEVEL)
	msg_void_i(
		window,
		sel_registerName("setCollectionBehavior:"),
		int(NS.WindowCollectionBehavior{.Transient, .FullScreenAuxiliary}),
	)
	msg_void_id(window, sel_registerName("setDelegate:"), delegate)

	view := msg_id0(view_class, sel_registerName("alloc"))
	view = msg_id_rect(view, sel_registerName("initWithFrame:"), frame)
	if view == nil {return false}
	msg_void_id(window, sel_registerName("setContentView:"), view)
	msg_void_bool(view, sel_registerName("setWantsLayer:"), true)

	layer := QC.MetalLayer.layer()
	if layer == nil {return false}
	layer->setDevice(device)
	layer->setPixelFormat(.BGRA8Unorm)
	layer->setFramebufferOnly(true)
	msg_void_bool(layer, sel_registerName("setOpaque:"), true)
	msg_void_id(view, sel_registerName("setLayer:"), rawptr(layer))

	if !view_init(rawptr(device)) {return false}
	if !macos.display_link_start(
		&panel_window.display_link,
		rawptr(view),
		rawptr(controller),
		"launcherFrame:",
	) {
		return false
	}
	macos.display_link_set_paused(&panel_window.display_link, true)

	panel_window.app = msg_id0(objc_getClass("NSApplication"), sel_registerName("sharedApplication"))
	msg_void_id(panel_window.app, sel_registerName("setDelegate:"), delegate)
	msg_void_i(panel_window.app, sel_registerName("setActivationPolicy:"), 1)
	status_bar := msg_id0(objc_getClass("NSStatusBar"), sel_registerName("systemStatusBar"))
	status_item := msg_id_f64(status_bar, sel_registerName("statusItemWithLength:"), -1)
	if status_item == nil {return false}
	status_button := msg_id0(status_item, sel_registerName("button"))
	if status_button == nil {return false}
	msg_void_id(status_button, sel_registerName("setTitle:"), nsstring(">_"))
	msg_void_id(status_button, sel_registerName("setToolTip:"), nsstring("hw_launcher"))
	msg_void_id(status_button, sel_registerName("setTarget:"), controller)
	msg_void_sel(status_button, sel_registerName("setAction:"), sel_registerName("launcherToggle:"))
	msg_void_u(status_button, sel_registerName("sendActionOn:"), NSEVENT_MASK_LEFT_MOUSE_UP)

	panel_window.device = device
	panel_window.queue = queue
	panel_window.layer = layer
	panel_window.window = window
	panel_window.view = view
	panel_window.controller = controller
	panel_window.delegate = delegate
	panel_window.status_item = status_item
	panel_window.status_button = status_button
	panel_sync_layer(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	return true
}

panel_position :: proc() {
	screen := msg_id0(objc_getClass("NSScreen"), sel_registerName("mainScreen"))
	visible := screen == nil ? Rect{{0, 0}, {1440, 900}} : msg_rect_0(screen, sel_registerName("visibleFrame"))
	width := f64(LAUNCHER_WIDTH)
	height := f64(LAUNCHER_HEIGHT)
	x := visible.origin.x+(f64(visible.size.width)-width)/2
	y := visible.origin.y+(f64(visible.size.height)-height)/2
	msg_void_rect_bool(
		panel_window.window,
		sel_registerName("setFrame:display:"),
		Rect{{x, y}, {width, height}},
		true,
	)
}

panel_sync_layer :: proc(width, height: f32) {
	if panel_window.layer == nil {return}
	scale := f32(1)
	if panel_window.window != nil {
		scale = f32(msg_f64_0(panel_window.window, sel_registerName("backingScaleFactor")))
	}
	panel_window.layer->setContentsScale(NS.Float(scale))
	panel_window.layer->setFrame({{0, 0}, {NS.Float(width), NS.Float(height)}})
	panel_window.layer->setDrawableSize({NS.Float(width*scale), NS.Float(height*scale)})
}

panel_make_first_responder :: proc() {
	if panel_window.window != nil && panel_window.view != nil {
		msg_void_id(panel_window.window, sel_registerName("makeFirstResponder:"), panel_window.view)
	}
}

panel_reset_caret :: proc() {
	if panel_window.caret_timer != nil {
		msg_void0(panel_window.caret_timer, sel_registerName("invalidate"))
		panel_window.caret_timer = nil
	}
	if !panel_window.visible || !input_focused() {return}
	panel_window.caret_timer = NS.Timer_scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeat(
		0.5,
		(^NS.Object)(panel_window.controller),
		NS.sel_registerName("launcherCaretBlink:"),
		nil,
		false,
	)
}

panel_request_frames :: proc(count: int = 3) {
	if !panel_window.visible {return}
	panel_window.frames_pending = max(panel_window.frames_pending, count)
	if panel_window.display_link.paused {
		macos.display_link_set_paused(&panel_window.display_link, false)
	}
}

panel_mark_dirty :: proc() {
	if !panel_window.visible {return}
	panel_request_frames()
	if panel_window.drawing || panel_window.draw_scheduled {return}
	panel_window.draw_scheduled = true
	dispatch_async_f(&_dispatch_main_q, nil, panel_draw_deferred)
}

panel_draw_deferred :: proc "c" (data: rawptr) {
	context = runtime.default_context()
	panel_window.draw_scheduled = false
	panel_draw()
}

panel_draw :: proc() {
	if !panel_window.visible || panel_window.layer == nil || panel_window.queue == nil {return}
	defer free_all(context.temp_allocator)
	panel_window.drawing = true
	defer panel_window.drawing = false

	hw_clay.set_pointer_state(
		&launcher_view.clay,
		panel_window.pointer_valid ? panel_window.pointer : {-1, -1},
		panel_window.pointer_down,
	)
	if panel_window.scroll_delta.x != 0 || panel_window.scroll_delta.y != 0 {
		hw_clay.update_scroll_containers(
			&launcher_view.clay,
			false,
			panel_window.scroll_delta,
			1.0/60.0,
		)
		panel_window.scroll_delta = {0, 0}
	}

	panel_sync_layer(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	drawable := panel_window.layer->nextDrawable()
	if drawable == nil {return}
	scale := f32(1)
	if panel_window.window != nil {
		scale = f32(msg_f64_0(panel_window.window, sel_registerName("backingScaleFactor")))
	}

	metal.begin_texture_frame(&launcher_view.gpu)
	coretext.begin_frame(&launcher_view.text, scale, metal.atlas_io(&launcher_view.gpu))
	draw.list_reset(&launcher_view.list)
	commands := view_begin_frame(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	accessibility_rebuild()
	view_render_commands(commands)
	coretext.flush(&launcher_view.text)

	command_buffer := panel_window.queue->commandBuffer()
	view_style := &launcher_view.style
	if !metal.encode_to_drawable(
		&launcher_view.gpu,
		rawptr(command_buffer),
		rawptr(drawable->texture()),
		&launcher_view.list,
		{LAUNCHER_WIDTH, LAUNCHER_HEIGHT},
		scale,
		hw_clay_ui.color_to_draw(view_style.background),
	) {
		fmt.eprintln("[hw_launcher] Metal encode failed")
		return
	}
	command_buffer->presentDrawable(drawable)
	command_buffer->commit()
	if panel_window.frames_pending > 0 {panel_window.frames_pending -= 1}
	if panel_window.frames_pending == 0 {
		macos.display_link_set_paused(&panel_window.display_link, true)
	}
}

panel_show :: proc() {
	if panel_window.visible {return}
	panel_position()
	panel_window.visible = true
	panel_window.pointer_valid = false
	panel_window.pointer_down = false
	msg_void_id(panel_window.window, sel_registerName("makeKeyAndOrderFront:"), nil)
	input_focus()
	panel_request_frames(3)
	panel_draw()
}

panel_window_hide :: proc() {
	if !panel_window.visible {return}
	panel_window.visible = false
	panel_window.pointer_valid = false
	panel_window.pointer_down = false
	panel_window.abort_pressed = false
	panel_window.scroll_delta = {}
	panel_window.frames_pending = 0
	macos.display_link_set_paused(&panel_window.display_link, true)
	_ = input_blur()
	if panel_window.caret_timer != nil {
		msg_void0(panel_window.caret_timer, sel_registerName("invalidate"))
		panel_window.caret_timer = nil
	}
	msg_void_id(panel_window.window, sel_registerName("orderOut:"), nil)
}

panel_toggle :: proc() {
	if panel_window.visible {panel_window_hide()} else {panel_show()}
}

panel_quit :: proc() {
	msg_void_id(panel_window.app, sel_registerName("terminate:"), nil)
}

panel_run :: proc() {
	if panel_window.app != nil {msg_void0(panel_window.app, sel_registerName("run"))}
}

panel_shutdown :: proc() {
	panel_window_hide()
	if panel_window.caret_timer != nil {
		msg_void0(panel_window.caret_timer, sel_registerName("invalidate"))
		panel_window.caret_timer = nil
	}
	macos.display_link_stop(&panel_window.display_link)
	if panel_window.status_item != nil {
		status_bar := msg_id0(objc_getClass("NSStatusBar"), sel_registerName("systemStatusBar"))
		msg_void_id(status_bar, sel_registerName("removeStatusItem:"), panel_window.status_item)
	}
	view_destroy()
	panel_window = {}
}

panel_frame_callback :: proc "c" (self: Id, command: Sel, timer: Id) {
	context = runtime.default_context()
	if !panel_window.visible || panel_window.frames_pending <= 0 {
		macos.display_link_set_paused(&panel_window.display_link, true)
		return
	}
	panel_draw()
}

panel_toggle_callback :: proc "c" (self: Id, command: Sel, sender: Id) {
	context = runtime.default_context()
	panel_toggle()
}

panel_quit_callback :: proc "c" (self: Id, command: Sel, sender: Id) {
	context = runtime.default_context()
	panel_quit()
}

panel_caret_blink :: proc "c" (self: Id, command: Sel, timer: Id) {
	context = runtime.default_context()
	panel_window.caret_timer = nil
	launcher_view.caret_visible = !launcher_view.caret_visible
	panel_mark_dirty()
	panel_reset_caret()
}

panel_accepts_first_responder :: proc "c" (self: Id, command: Sel) -> bool {return true}
panel_accepts_first_mouse :: proc "c" (self: Id, command: Sel, event: Id) -> bool {return true}
panel_can_become_key :: proc "c" (self: Id, command: Sel) -> bool {return true}

panel_did_resign_key :: proc "c" (self: Id, command: Sel, notification: Id) {
	context = runtime.default_context()
	panel_window_hide()
}

panel_will_terminate :: proc "c" (self: Id, command: Sel, notification: Id) {
	context = runtime.default_context()
	launcher_shutdown()
}

panel_native_rect :: proc(rect: hw_clay.Bounding_Box) -> Rect {
	return {{f64(rect.x), f64(launcher_view.height-rect.y-rect.height)},
		{f64(rect.width), f64(rect.height)}}
}

panel_rect_to_screen :: proc(rect: hw_clay.Bounding_Box) -> Rect {
	if panel_window.view == nil || panel_window.window == nil {return {}}
	local := panel_native_rect(rect)
	window_rect := msg_rect_rect_id(panel_window.view, sel_registerName("convertRect:toView:"), local, nil)
	return msg_rect_rect(panel_window.window, sel_registerName("convertRectToScreen:"), window_rect)
}

panel_pointer_update :: proc(event: ^NS.Event, down: bool) {
	if panel_window.view == nil {return}
	location := event->locationInWindow()
	point := (^NS.View)(panel_window.view)->convertPointFromView(location, nil)
	panel_window.pointer = {f32(point.x), f32(LAUNCHER_HEIGHT)-f32(point.y)}
	panel_window.pointer_valid = true
	panel_window.pointer_down = down
	panel_mark_dirty()
}

panel_mouse_down :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	panel_pointer_update(event, true)
	panel_pointer_press(panel_window.pointer, uint(event->clickCount()))
}

panel_mouse_up :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	panel_pointer_update(event, false)
	panel_pointer_release(panel_window.pointer)
}

panel_pointer_press :: proc(point: hw_clay.Vector2, clicks: uint) {
	panel_window.abort_pressed = view_abort_at_point(point)
	input_pointer_begin({f64(point.x), f64(point.y)}, clicks)
}

panel_pointer_release :: proc(point: hw_clay.Vector2) {
	text_input.end_pointer_selection(&launcher.input_state)
	if panel_window.abort_pressed && view_abort_at_point(point) {
		backend_abort(&launcher)
	}
	panel_window.abort_pressed = false
	panel_mark_dirty()
}

panel_mouse_dragged :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	panel_pointer_update(event, true)
	_ = input_pointer_update({f64(panel_window.pointer.x), f64(panel_window.pointer.y)})
}

panel_mouse_moved :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	panel_pointer_update(event, panel_window.pointer_down)
}

panel_scroll :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	delta_x, delta_y := event->scrollingDelta()
	launcher.follow_tail = false
	panel_window.scroll_delta.x += f32(delta_x)
	panel_window.scroll_delta.y += f32(delta_y)
	panel_mark_dirty()
}

panel_key_down :: proc "c" (self: Id, command: Sel, event: ^NS.Event) {
	context = runtime.default_context()
	modifiers := event->modifierFlags()
	key := uint(event->keyCode())
	if .Command in modifiers && key == 12 {panel_quit(); return}
	if .Command in modifiers && key == 47 {backend_abort(&launcher); return}
	if key == 53 {panel_window_hide(); return}
	input_interpret_event(rawptr(event))
}
