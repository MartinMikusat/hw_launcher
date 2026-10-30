package delta_ui

import "core:fmt"
import clay "hw_clay:."
import modules "../powermodules"

// Flow elements inherit their caller's clipping and layer, including article
// previews inside a modal. Geometry owns the row and column dimensions.
power_module_diagram :: proc(style:^Style,ctx:^clay.Context,layout:^modules.Diagram,id:clay.Element_Id) {
    assert(style!=nil && layout!=nil)
    if !element(ctx,{layout={sizing={clay.fixed(layout.width),clay.fixed(layout.height)},layout_direction=.Top_To_Bottom}},id) {return}
    defer clay.pop_element(ctx)
    header_index,card_index:=0,0
    bottom:f32
    labels:=modules.DESCRIPTOR_LABELS
    for panel,index in layout.panels[:layout.panel_count] {
        if element(ctx,{layout={sizing={clay.fixed(panel.width),clay.fixed(panel.y-bottom)}}}) {clay.pop_element(ctx)}
        bottom=panel.y+panel.height
        if !element(ctx,{layout={sizing={clay.fixed(panel.width),clay.fixed(panel.height)},layout_direction=.Top_To_Bottom},border={color=style.foreground,width=clay.border_outside(1)}},clay.id_indexed(fmt.tprintf("PowerModulePanel-%d",id.id),u32(index))) {return}
        if element(ctx,{layout={sizing={clay.fixed(panel.width),clay.fixed(style.row_height)}}}) {clay.pop_element(ctx)}
        if !element(ctx,{layout={sizing={clay.fixed(panel.width),clay.grow()}}}) {clay.pop_element(ctx);return}
        if element(ctx,{layout={sizing={clay.fixed(2*style.ch),clay.fixed(1)}}}) {clay.pop_element(ctx)}
        if !element(ctx,{layout={sizing={clay.fixed(panel.width-4*style.ch),clay.grow()},layout_direction=.Top_To_Bottom}}) {clay.pop_element(ctx);clay.pop_element(ctx);return}
        if element(ctx,{layout={sizing={clay.grow(),clay.fixed(style.row_height)}}}) {
            for header_index<layout.header_count && layout.headers[header_index].box.y<bottom {
                header:=layout.headers[header_index]
                if element(ctx,{layout={sizing={clay.fixed(header.box.width),clay.fixed(header.box.height)},child_alignment={x=.Center,y=.Center}},background_color=COLOR_ONLINE},power_module_header_id(id,header_index)) {text(style,ctx,header.name,COLOR_BLACK);clay.pop_element(ctx)}
                header_index+=1
                if header_index<layout.header_count && layout.headers[header_index].box.y<bottom {if element(ctx,{layout={sizing={clay.fixed(style.ch),clay.fixed(1)}}}) {clay.pop_element(ctx)}}
            }
            clay.pop_element(ctx)
        }
        for card_index<layout.module_count && layout.modules[card_index].box.y<bottom {
            if element(ctx,{layout={sizing={clay.grow(),clay.fixed(style.ch)}}}) {clay.pop_element(ctx)}
            row:=layout.modules[card_index].box
            if !element(ctx,{layout={sizing={clay.grow(),clay.fixed(row.height)}}}) {break}
            for card_index<layout.module_count && layout.modules[card_index].box.y==row.y {
                card:=layout.modules[card_index]
                if element(ctx,{layout={sizing={clay.fixed(card.box.width),clay.fixed(card.box.height)},padding=clay.padding_all(u16(style.ch)),layout_direction=.Top_To_Bottom},border={color=style.foreground,width=clay.border_outside(1)}},power_module_card_id(id,card_index)) {
                    for value,field in modules.descriptor_values(card.module) {
                        if value=="" {continue}
                        if element(ctx,{layout={sizing={clay.grow(),clay.fixed(style.row_height)}}}) {
                            text(style,ctx,labels[field])
                            if element(ctx,{layout={sizing={clay.grow(),clay.fixed(style.row_height)},child_alignment={x=.Right}}}) {text(style,ctx,value);clay.pop_element(ctx)}
                            clay.pop_element(ctx)
                        }
                    }
                    clay.pop_element(ctx)
                }
                card_index+=1
                if card_index<layout.module_count && layout.modules[card_index].box.y==row.y {if element(ctx,{layout={sizing={clay.fixed(style.ch),clay.fixed(1)}}}) {clay.pop_element(ctx)}}
            }
            clay.pop_element(ctx)
        }
        clay.pop_element(ctx);clay.pop_element(ctx);clay.pop_element(ctx)
    }
}

power_module_header_id :: proc(id:clay.Element_Id,index:int)->clay.Element_Id {return clay.id_indexed(fmt.tprintf("PowerModuleHeader-%d",id.id),u32(index))}
power_module_card_id :: proc(id:clay.Element_Id,index:int)->clay.Element_Id {return clay.id_indexed(fmt.tprintf("PowerModuleCard-%d",id.id),u32(index))}
