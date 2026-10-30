// Shared terminal-style primitives; the Delta Support DESIGN.md is authoritative.
package delta_ui

import "core:math"
import text_input "components:text_input"
import settings "delta_support:settings"
import hw_clay "hw_clay:."
import hw_clay_ui "ui_framework:clay"
import ui "ui_framework:core"
import coretext "ui_framework:coretext"
import draw "ui_framework:draw"

FONT_MONO :: ui.Font_Handle(1)
FONT_NAME :: "JetBrainsMono-Regular"
// Reading faces: Inter for text, Bitstream Charter for headings. They keep their own letter spacing.
FONT_SANS :: ui.Font_Handle(2)
FONT_SERIF :: ui.Font_Handle(3)
FONT_SERIF_BOLD :: ui.Font_Handle(4)
FONT_SANS_BOLD :: ui.Font_Handle(5)
FONT_SANS_ITALIC :: ui.Font_Handle(6)
FONT_SANS_BOLD_ITALIC :: ui.Font_Handle(7)
FONT_SANS_NAME :: "Inter-Regular"
FONT_SERIF_NAME :: "CharterRegular"
FONT_SERIF_BOLD_NAME :: "CharterBold"
FONT_SANS_DATA :: #load("fonts/Inter-Regular.woff2")
FONT_SERIF_DATA :: #load("fonts/Charter-Regular.woff2")
FONT_SERIF_BOLD_DATA :: #load("fonts/Charter-Bold.woff2")
// Inter's italics are its slanted (slnt -10) instances, generated from the variable font.
FONT_SANS_BOLD_DATA :: #load("fonts/Inter-Bold.woff2")
FONT_SANS_ITALIC_DATA :: #load("fonts/Inter-Italic.woff2")
FONT_SANS_BOLD_ITALIC_DATA :: #load("fonts/Inter-BoldItalic.woff2")
FONT_SANS_BOLD_NAME :: "Inter-Bold"
FONT_SANS_ITALIC_NAME :: "Inter-Italic"
FONT_SANS_BOLD_ITALIC_NAME :: "Inter-BoldItalic"
// Every glyph advances 0.8 px less than the font's 0.6 em (7 px at 13 px); the Windows text backend applies the same figure.
TRACKING_PIXELS :: f32(0.8)
FONT_DATA :: #load("fonts/JetBrainsMono-Regular.woff2")
// Fixed text colors on status accents; ordinary UI neutrals come from the theme below.
COLOR_WHITE :: hw_clay.Color{230, 230, 230, 255}
COLOR_BLACK :: hw_clay.Color{26, 26, 26, 255}
COLOR_DISABLED :: hw_clay.Color{128, 128, 128, 255}
// The only green: all green labels use this fill with COLOR_BLACK, in both themes.
// Unlabelled graphics use the fill directly; interactive fills retain Online's hover.
COLOR_ONLINE :: hw_clay.Color{190, 242, 99, 255}
COLOR_ONLINE_HOVER :: hw_clay.Color{163, 230, 53, 255}
COLOR_OFFLINE :: hw_clay.Color{244, 52, 52, 255}
COLOR_OFFLINE_HOVER :: hw_clay.Color{220, 38, 38, 255}
COLOR_WARNING :: hw_clay.Color{237, 108, 12, 255}
COLOR_SESSION_PLUG :: hw_clay.Color{2, 132, 199, 255} // Electrobun text-sky-600.
COLOR_MINIMAP_WARNING :: hw_clay.Color{255, 165, 61, 6.375} // Electrobun: hsl(32 100% 62%) at 2.5%.
COLOR_CLEAR :: hw_clay.Color{0, 0, 0, 0}

// Electrobun ChargerEvents case identities; these are categorical accents, not
// additional neutral shades. Assignment follows first chronological appearance.
COLOR_CASE_CYCLE :: [7]hw_clay.Color{
	{37,99,235,255}, {239,68,68,255}, {234,179,8,255}, COLOR_ONLINE,
	{6,182,212,255}, {249,115,22,255}, {168,85,247,255},
}

Style :: struct {
	text_size: u16,
	row_height: f32,
	ch: f32,
	modal_margin: u16,
	background, foreground, danger, modal_backdrop: hw_clay.Color,
	copy_text, copy_hover: hw_clay.Color,
	session_warning, session_status_text: hw_clay.Color,
	session_soc_track: hw_clay.Color,
	chart_bar, chart_error: hw_clay.Color,
}

font_registered: bool

foreign import style_cf "system:CoreFoundation.framework"
foreign style_cf {
	CFDataCreate :: proc "c" (allocator: rawptr, bytes: rawptr, length: int) -> rawptr ---
}

foreign import style_cg "system:CoreGraphics.framework"
foreign style_cg {
	CGDataProviderCreateWithCFData :: proc "c" (data: rawptr) -> rawptr ---
	CGDataProviderRelease :: proc "c" (provider: rawptr) ---
	CGFontCreateWithDataProvider :: proc "c" (provider: rawptr) -> rawptr ---
	CGFontRelease :: proc "c" (font: rawptr) ---
}

foreign import style_ct "system:CoreText.framework"
foreign style_ct {
	CTFontManagerRegisterGraphicsFont :: proc "c" (font: rawptr, error: ^rawptr) -> bool ---
}

initialize :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, pixels: int, theme: settings.Theme) {
	assert(renderer != nil && renderer.text != nil)
	if !font_registered {
		// Embedded, process-local registration: no font installation or runtime path.
		font_registered = true
		for data in ([7][]byte{FONT_DATA, FONT_SANS_DATA, FONT_SERIF_DATA, FONT_SERIF_BOLD_DATA, FONT_SANS_BOLD_DATA, FONT_SANS_ITALIC_DATA, FONT_SANS_BOLD_ITALIC_DATA}) {
			cf_data := CFDataCreate(nil, raw_data(data), len(data))
			assert(cf_data != nil)
			defer coretext.CFRelease(cf_data)
			provider := CGDataProviderCreateWithCFData(cf_data)
			assert(provider != nil)
			defer CGDataProviderRelease(provider)
			font := CGFontCreateWithDataProvider(provider)
			assert(font != nil, "embedded font must decode")
			defer CGFontRelease(font)
			error: rawptr
			registered := CTFontManagerRegisterGraphicsFont(font, &error)
			if error != nil {coretext.CFRelease(error)}
			assert(registered, "embedded font must register; no silent substitute")
		}
	}
	hw_clay_ui.renderer_register_font(renderer, FONT_MONO, FONT_NAME)
	hw_clay_ui.renderer_register_font(renderer, FONT_SANS, FONT_SANS_NAME, tracked = false)
	hw_clay_ui.renderer_register_font(renderer, FONT_SERIF, FONT_SERIF_NAME, tracked = false)
	hw_clay_ui.renderer_register_font(renderer, FONT_SERIF_BOLD, FONT_SERIF_BOLD_NAME, tracked = false)
	hw_clay_ui.renderer_register_font(renderer, FONT_SANS_BOLD, FONT_SANS_BOLD_NAME, tracked = false)
	hw_clay_ui.renderer_register_font(renderer, FONT_SANS_ITALIC, FONT_SANS_ITALIC_NAME, tracked = false)
	hw_clay_ui.renderer_register_font(renderer, FONT_SANS_BOLD_ITALIC, FONT_SANS_BOLD_ITALIC_NAME, tracked = false)
	update(style, renderer, pixels, theme)
}

update :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, root_font_pixels: int, theme: settings.Theme) {
	when ODIN_OS == .Darwin {renderer.text.tracking = -TRACKING_PIXELS}
	pixels := u16(settings.root_font_pixels_clamp(root_font_pixels))
	if style.text_size != pixels || style.ch == 0 {
		style.text_size = pixels
		style.row_height = math.ceil(f32(pixels) * 1.2)
		config := hw_clay.Text_Config{font_id = u16(FONT_MONO), font_size = pixels}
		style.ch = math.ceil(hw_clay_ui.measure_text("0", &config, renderer).width)
		assert(style.ch > 0)
	}
	dark := theme == .Dark
	// Electrobun terminal/dark theme primitives, rounded to sRGB bytes.
	style.background = dark ? hw_clay.Color{23,23,23,255} : hw_clay.Color{249,248,246,255}
	style.foreground = dark ? hw_clay.Color{209,209,209,255} : hw_clay.Color{46,46,46,255}
	// Every modal uses black at 80% opacity in both themes; panels stay opaque.
	style.modal_backdrop = {0, 0, 0, 204}
	style.modal_margin = 2 * pixels
	style.chart_bar = dark ? hw_clay.Color{56,56,56,255} : hw_clay.Color{224,224,224,255}
	style.chart_error = {244,52,52,204} // --destructive / 0.8, over the total bar.
	style.danger = dark ? COLOR_OFFLINE : hw_clay.Color{196, 37, 37, 255}
	// Electrobun --theme-blue (205 90% 50%/58%); copyable-text:hover brightens 1.1x.
	style.copy_text = dark ? hw_clay.Color{52,164,244,255} : hw_clay.Color{13,147,242,255}
	c := style.copy_text
	style.copy_hover = {min(255,c.r*1.1),min(255,c.g*1.1),min(255,c.b*1.1),255}
	// Electrobun's named theme yellow and text on warning/error diagnostic badges.
	style.session_warning = dark ? hw_clay.Color{250,175,46,255} : hw_clay.Color{249,160,6,255}
	style.session_status_text = dark ? hw_clay.Color{23,23,23,255} : hw_clay.Color{255,255,255,255}
	// ChargeIndication's quantitative track is foreground at 20%, not disabled text.
	style.session_soc_track = style.foreground
	style.session_soc_track.a = 51
}

element :: proc(ctx: ^hw_clay.Context, config: hw_clay.Element_Declaration, id: hw_clay.Element_Id = {}) -> bool {
	hw_clay.open_element(ctx, id)
	declaration := config
	if declaration.clip.horizontal || declaration.clip.vertical {
		// get_scroll_offset addresses the open element, never its parent.
		declaration.clip.child_offset = hw_clay.get_scroll_offset(ctx)
	}
	hw_clay.configure_element(ctx, declaration)
	return true
}

text :: proc(style: ^Style, ctx: ^hw_clay.Context, text: string, color := COLOR_CLEAR) {
	hw_clay.push_text(ctx, text, {font_id = u16(FONT_MONO), font_size = style.text_size, line_height = u16(style.row_height), color = color.a == 0 ? style.foreground : color, wrap_mode = .None})
}

text_width :: proc(style: ^Style, ctx: ^hw_clay.Context, text: string) -> f32 {
	config := hw_clay.Text_Config{font_id = u16(FONT_MONO), font_size = style.text_size}
	return ctx.measure_text(text, &config, ctx.measure_text_user_data).width
}

control_color :: proc(style: ^Style, disabled, inverted: bool) -> hw_clay.Color {
	return disabled ? COLOR_DISABLED : (inverted ? style.background : style.foreground)
}

control_text :: proc(style: ^Style, ctx: ^hw_clay.Context, value: string, disabled, inverted: bool) {
	text(style, ctx, value, control_color(style, disabled, inverted))
}

wrapped_text :: proc(style: ^Style, ctx: ^hw_clay.Context, text: string, color := COLOR_CLEAR, alignment: hw_clay.Text_Alignment = .Left) {
	hw_clay.push_text(ctx, text, {font_id = u16(FONT_MONO), font_size = style.text_size, line_height = u16(style.row_height), color = color.a == 0 ? style.foreground : color, wrap_mode = .Words, text_alignment = alignment})
}

message :: proc(style: ^Style, ctx: ^hw_clay.Context, text: string, failed: bool) {
	hw_clay.push_text(ctx, text, {font_id = u16(FONT_MONO), font_size = style.text_size, line_height = u16(style.row_height), color = failed ? style.danger : style.foreground, wrap_mode = .Words})
}

input_text_bounds :: proc(style: ^Style, box: hw_clay.Bounding_Box) -> hw_clay.Bounding_Box {
	result := box
	prompt_width := min(style.ch, max(0, box.width))
	result.x += prompt_width
	result.width = max(0, box.width - prompt_width)
	return result
}

render_input :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, box: draw.Rect, text, display, placeholder: string, input: ^text_input.State, active, caret_visible: bool) {
	foreground := hw_clay_ui.color_to_draw(style.foreground)
	background := hw_clay_ui.color_to_draw(style.background)
	draw.push_clip(renderer.list, box)
	defer draw.pop_clip(renderer.list)
	prompt := coretext.shape(renderer.text, FONT_MONO, ">", f32(style.text_size), 0, 0, false)
	origin_y := box.y + (box.h-prompt.metrics.ascent-prompt.metrics.descent)/2 + prompt.metrics.descent
	coretext.emit_shaped_run(renderer.text, renderer.list, prompt, {box.x, origin_y}, foreground, "")
	text_box := input_text_bounds(style, {box.x, box.y, box.w, box.h})
	box := draw.Rect{text_box.x, text_box.y, text_box.width, text_box.height}
	if box.w <= 0 {return}
	draw.push_clip(renderer.list, box)
	defer draw.pop_clip(renderer.list)
	// Placeholder text is drawing-only; selection, copying and IME keep the real value.
	shown := display == "" ? placeholder : display
	run := coretext.shape(renderer.text, FONT_MONO, shown == "" ? " " : shown, f32(style.text_size), 0, 0, false)
	caret := coretext.offset_for_utf16_index(run, text_input.utf16_index_for_byte_offset(text, input.caret_byte_offset), renderer.text.backing_scale)
	scroll: f32
	if active {scroll = f32(text_input.update_horizontal_scroll(input, f64(caret), f64(max(0, box.w - 2))))}
	origin := ui.Vec2{box.x - scroll, box.y + (box.h - run.metrics.ascent - run.metrics.descent) / 2 + run.metrics.descent}
	coretext.emit_shaped_run(renderer.text, renderer.list, run, origin, display == "" ? hw_clay_ui.color_to_draw(COLOR_DISABLED) : foreground, "")
	if !active {return}
	start, end := text_input.selection_bounds(input, text)
	if end > start {
		x0 := coretext.offset_for_utf16_index(run, text_input.utf16_index_for_byte_offset(text, start), renderer.text.backing_scale)
		x1 := coretext.offset_for_utf16_index(run, text_input.utf16_index_for_byte_offset(text, end), renderer.text.backing_scale)
		selection := draw.Rect{origin.x + x0, box.y + 1, x1 - x0, box.h - 1}
		draw.solid(renderer.list, selection, foreground)
		draw.push_clip(renderer.list, selection)
		coretext.emit_shaped_run(renderer.text, renderer.list, run, origin, background, "")
		draw.pop_clip(renderer.list)
	}
	if start == end && caret_visible {
		draw.solid(renderer.list, {origin.x + caret, box.y + 2, 1, box.h - 3}, foreground)
	}
	if input.has_marked_text {
		draw.solid(renderer.list, {box.x, box.y + 2, box.w, 1}, foreground)
	}
}

render_cell :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, box: draw.Rect, value: string, ink: hw_clay.Color, truncate:=true) {
	if box.w <= 0 || len(value) == 0 {return}
	run := coretext.shape(renderer.text, FONT_MONO, value, f32(style.text_size), 0, truncate ? box.w : 0, truncate)
	assert(run != nil)
	draw.push_clip(renderer.list, box)
	origin := ui.Vec2{box.x, box.y + (box.h - run.metrics.ascent - run.metrics.descent) / 2 + run.metrics.descent}
	color := ink
	if color == COLOR_ONLINE {
		// Fit the green fill to the label, not the unused remainder of its column.
		draw.solid(renderer.list, {box.x,box.y,min(box.w,run.metrics.width),box.h}, hw_clay_ui.apply_overlays(renderer, hw_clay_ui.color_to_draw(COLOR_ONLINE)))
		color = COLOR_BLACK
	}
	coretext.emit_shaped_run(renderer.text, renderer.list, run, origin, hw_clay_ui.apply_overlays(renderer, hw_clay_ui.color_to_draw(color)), "")
	draw.pop_clip(renderer.list)
}

render_command :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, command: hw_clay.Render_Command) {
	assert(command.command_type != .Custom)
	one := [1]hw_clay.Render_Command{command}
	// Apply the same green-label contract to ordinary and wrapped text.
	if command.command_type == .Text && command.render_data.(hw_clay.Text_Render_Data).text_color == COLOR_ONLINE {
		data := command.render_data.(hw_clay.Text_Render_Data)
		box := hw_clay_ui.rect_to_draw(renderer, command.bounding_box)
		box.y -= (style.row_height-box.h)/2
		box.h = style.row_height
		draw.solid(renderer.list, box, hw_clay_ui.apply_overlays(renderer, hw_clay_ui.color_to_draw(COLOR_ONLINE)))
		data.text_color = COLOR_BLACK
		colored := [1]hw_clay.Render_Command{command}
		colored[0].render_data = data
		hw_clay_ui.render_commands(renderer, colored[:])
		return
	}
	hw_clay_ui.render_commands(renderer, one[:])
	return
}

render_progress_button :: proc(style: ^Style, renderer: ^hw_clay_ui.Renderer, box: draw.Rect, value, status_text: string, ink: hw_clay.Color, progress: f32) {
	if box.w <= 0 {return}
	draw.push_clip(renderer.list, box)
	defer draw.pop_clip(renderer.list)
	ch := style.ch
	// Keep the right-aligned status intact; the family name yields its space first.
	status_width := max(f32(0), box.w-2*ch)
	status := coretext.shape(renderer.text, FONT_MONO, status_text, f32(style.text_size), 0, status_width, true)
	label_width := max(f32(0), box.w-status.metrics.width-3*ch)
	label := coretext.shape(renderer.text, FONT_MONO, value, f32(style.text_size), 0, max(f32(1),label_width), true)
	left := coretext.shape(renderer.text, FONT_MONO, "[", f32(style.text_size), 0, 0, false)
	right := coretext.shape(renderer.text, FONT_MONO, "]", f32(style.text_size), 0, 0, false)
	y := box.y + (box.h-left.metrics.ascent-left.metrics.descent)/2 + left.metrics.descent
	color := hw_clay_ui.apply_overlays(renderer, hw_clay_ui.color_to_draw(ink))
	coretext.emit_shaped_run(renderer.text, renderer.list, left, {box.x,y}, color, "")
	// Truncation can still exceed a sliver of room; then the status takes the whole button.
	if label_width > 0 && label.metrics.width <= label_width {coretext.emit_shaped_run(renderer.text, renderer.list, label, {box.x+ch,y}, color, "")}
	coretext.emit_shaped_run(renderer.text, renderer.list, status, {box.x+box.w-ch-status.metrics.width,y}, color, "")
	coretext.emit_shaped_run(renderer.text, renderer.list, right, {box.x+box.w-ch,y}, color, "")
	if progress >= 0 {
		x := box.w*clamp(progress,0,1)
		remainder := hw_clay_ui.color_to_draw(style.background)
		remainder.a = 0.3
		draw.solid(renderer.list, {box.x+x,box.y,box.w-x,box.h}, remainder)
	}
}
