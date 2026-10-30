package delta_ui

import "core:fmt"
import "core:strings"
import hw_clay "hw_clay:."

section_heading :: proc(style: ^Style, ctx: ^hw_clay.Context, label: string, width: f32, render_label: proc(^hw_clay.Context,string,hw_clay.Sizing_Axis,hw_clay.Color)) {
    heading:=section_label(style,ctx,label,width)
	if !element(ctx,{layout={sizing={hw_clay.fixed(width),hw_clay.fixed(style.row_height)},child_alignment={x=.Center}}}) {return}
	defer hw_clay.pop_element(ctx)
	render_label(ctx,heading,hw_clay.fit({max=width}),style.foreground)
}

Check_State :: enum {Off, Include, Exclude}
CHECK_LABELS := [Check_State]string{.Off="Not set", .Include="Included", .Exclude="Excluded"}

// CheckboxTriple: a fixed 3ch marker, 1ch internal gap, then the unbracketed label.
// The owning control supplies full-row hover/focus inversion and its hit target.
triple_checkbox :: proc(style: ^Style, ctx: ^hw_clay.Context, label: string, state: Check_State, disabled, inverted: bool, render_label: proc(^hw_clay.Context,string,hw_clay.Sizing_Axis,hw_clay.Color)) {
	if !element(ctx, {layout={sizing={hw_clay.grow(),hw_clay.fixed(style.row_height)},child_gap=u16(style.ch)}}) {return}
	defer hw_clay.pop_element(ctx)
	color := control_color(style,disabled,inverted)
	marker,fill,mark_color:=check_appearance(style,state,disabled,inverted)
	if element(ctx, {layout={sizing={hw_clay.fixed(3*style.ch),hw_clay.fixed(style.row_height)},child_alignment={x=.Center}},background_color=fill}) {
		text(style,ctx,marker,mark_color)
		hw_clay.pop_element(ctx)
	}
	render_label(ctx,label,hw_clay.grow(),color)
}


Search_Geometry :: struct {filters,results:hw_clay.Bounding_Box}
search_geometry :: proc(width,height,top,ch:f32)->Search_Geometry {
    filters:=max(20*ch,min(32*ch,width*0.36))
    return {{0,top,filters,max(0,height-top-2*ch)},
        {filters+2*ch,top,max(ch,width-6*ch-filters),max(0,height-top-2*ch)}}
}

section_label :: proc(style:^Style,ctx:^hw_clay.Context,label:string,width:f32)->string {
    assert(width>0)
    dash_width:=text_width(style,ctx,"-");assert(dash_width>0)
    count:=int(max(0,(width-text_width(style,ctx,label))/dash_width))
    dashes:=strings.repeat("-",count,context.temp_allocator) or_else ""
    return fmt.tprintf("%s%s%s",dashes[:count/2],label,dashes[count/2:])
}
check_appearance :: proc(style:^Style,state:Check_State,disabled,inverted:bool)->(marker:string,fill,ink:hw_clay.Color) {
    color:=control_color(style,disabled,inverted)
    fill=disabled || state==.Off ? COLOR_CLEAR : state==.Include ? COLOR_ONLINE : COLOR_OFFLINE
    ink=disabled || state==.Off ? color : state==.Include ? COLOR_BLACK : style.session_status_text
    marker=state==.Include ? "[+]" : state==.Exclude ? "[-]" : "[ ]"
    return
}
