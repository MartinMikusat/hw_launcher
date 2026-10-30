package delta_ui

import hw_clay "hw_clay:."

Settings_Geometry :: struct {
	panel: hw_clay.Bounding_Box,
	rail_width: f32,
	compact: bool,
}

settings_geometry :: proc(width, height, ch, modal_margin, font_size: f32) -> Settings_Geometry {
	w := min(width - 4 * ch, 112 * font_size)
	h := max(0, min(height - 2 * modal_margin, 68 * font_size))
	compact := w < 68 * ch
	return {{(width - w) / 2, modal_margin, w, h}, compact ? w : 24 * ch, compact}
}

modal_backdrop :: proc(ctx: ^hw_clay.Context, style: ^Style, id: hw_clay.Element_Id, z_index: i16 = 90) -> bool {
    return element(ctx, {
        layout = {sizing = {hw_clay.grow(), hw_clay.grow()},
            padding = {top = style.modal_margin, bottom = style.modal_margin},
            child_alignment = {x = .Center, y = .Top}},
        background_color = style.modal_backdrop,
        floating = {attach_to = .Root, z_index = z_index, pointer_capture_mode = .Capture},
    }, id)
}
