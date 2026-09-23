package launcher

import "core:fmt"
import "core:os"
import "core:strings"
import MTL "vendor:darwin/Metal"
import NS "core:sys/darwin/Foundation"
import delta_settings "delta_support:settings"
import text_input "components:text_input"
import hw_clay_ui "hw_clay:ui_framework"
import coretext "ui_framework:coretext"
import draw "ui_framework:draw"
import metal "ui_framework:metal"

get_bytes :: proc(receiver: Id, bytes: []u8, bytes_per_row: uint, width, height: uint) {
	send := transmute(proc "c" (
		_: Id,
		_: rawptr,
		_: rawptr,
		_: uint,
		_: MTL.Region,
		_: uint,
	))metal.send_address
	region := MTL.Region{size = MTL.Size{NS.Integer(width), NS.Integer(height), 1}}
	send(receiver, sel_registerName("getBytes:bytesPerRow:fromRegion:mipmapLevel:"), raw_data(bytes), bytes_per_row, region, 0)
}

write_ppm :: proc(path: string, pixels: []u8, width, height: int) -> bool {
	file, create_error := os.create(path)
	if create_error != os.ERROR_NONE {return false}
	defer os.close(file)
	_, write_error := os.write_string(file, fmt.tprintf("P6\n%d %d\n255\n", width, height))
	if write_error != os.ERROR_NONE {return false}
	row := make([]u8, width*3, context.temp_allocator)
	defer delete(row, context.temp_allocator)
	for y in 0 ..< height {
		for x in 0 ..< width {
			pixel := (y*width+x)*4
			row[x*3+0] = pixels[pixel+2]
			row[x*3+1] = pixels[pixel+1]
			row[x*3+2] = pixels[pixel+0]
		}
		if _, row_error := os.write(file, row); row_error != os.ERROR_NONE {return false}
	}
	return true
}

offscreen_fixture :: proc() {
	transcript_append(
		&launcher.transcript,
		.User,
		"Summarize the launcher architecture and run the focused tests.",
	)
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_start", role = "Assistant"})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "message_update", role = "Assistant",
		text = "I will inspect the project structure, then run the smallest relevant checks.",
	})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "message_end", role = "Assistant",
		text = "I will inspect the project structure, then run the smallest relevant checks.",
	})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "tool_start",
		id = "fixture-tool-1",
		name = "bash",
		arguments = "./test.sh",
	})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "tool_end",
		id = "fixture-tool-1",
		text = "5 tests passed",
	})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{type = "message_start", role = "Assistant"})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "message_update", role = "Assistant",
		text = "The Odin backend and launcher protocol are passing. The remaining work is visual acceptance and manual window testing.",
	})
	launcher_apply_backend_event(&launcher, Backend_Event_Wire{
		type = "message_end", role = "Assistant",
		text = "The Odin backend and launcher protocol are passing. The remaining work is visual acceptance and manual window testing.",
	})
	launcher.backend_status = .Ready
	launcher.input = strings.clone("Show the remaining gaps")
	_ = text_input.focus(&launcher.input_state, LAUNCHER_INPUT_FIELD, launcher.input)
	text_input.move_line_end(&launcher.input_state, launcher.input, false)
	launcher.follow_tail = true
}

render_offscreen :: proc(
	path: string,
	width, height: int,
	scale: f32,
	theme: delta_settings.Theme,
) -> bool {
	if !objc_initialize() {return false}
	pool := msg_id0(msg_id0(objc_getClass("NSAutoreleasePool"), sel_registerName("alloc")), sel_registerName("init"))
	defer msg_void0(pool, sel_registerName("drain"))

	launcher = {}
	launcher_state_init(&launcher)
	defer launcher_state_destroy(&launcher)
	offscreen_fixture()
	device := MTL.CreateSystemDefaultDevice()
	if device == nil {return false}
	queue := device->newCommandQueue()
	if queue == nil {return false}
	if !view_init(rawptr(device)) {return false}
	launcher_view.theme = theme
	launcher_view.theme_follows_system = false
	defer view_destroy()
	pixel_width := int(f32(width)*scale)
	pixel_height := int(f32(height)*scale)
	descriptor := msg_id_u_u_u_bool(
		objc_getClass("MTLTextureDescriptor"),
		sel_registerName("texture2DDescriptorWithPixelFormat:width:height:mipmapped:"),
		80,
		uint(pixel_width),
		uint(pixel_height),
		false,
	)
	target := msg_id_id(device, sel_registerName("newTextureWithDescriptor:"), descriptor)
	if target == nil {return false}

	for _ in 0 ..< 3 {
		metal.begin_texture_frame(&launcher_view.gpu)
		coretext.begin_frame(&launcher_view.text, scale, metal.atlas_io(&launcher_view.gpu))
		draw.list_reset(&launcher_view.list)
		commands := view_begin_frame(f32(width), f32(height))
		view_render_commands(commands)
		coretext.flush(&launcher_view.text)
		command_buffer := queue->commandBuffer()
		if !metal.encode_to_drawable(
			&launcher_view.gpu,
			rawptr(command_buffer),
			rawptr(target),
			&launcher_view.list,
			{f32(width), f32(height)},
			scale,
			hw_clay_ui.color_to_draw(launcher_view.style.background),
		) {
			return false
		}
		msg_void0(command_buffer, sel_registerName("commit"))
		msg_void0(command_buffer, sel_registerName("waitUntilCompleted"))
		free_all(context.temp_allocator)
	}

	pixels := make([]u8, pixel_width*pixel_height*4, context.allocator)
	defer delete(pixels)
	get_bytes(target, pixels, uint(pixel_width*4), uint(pixel_width), uint(pixel_height))
	return write_ppm(path, pixels, pixel_width, pixel_height)
}
