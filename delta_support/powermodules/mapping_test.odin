package powermodules

import "core:strings"
import "core:testing"
import "core:math"

@(test)
mapping_projection_preserves_all_catalog_values :: proc(t:^testing.T) {
    mappings,ok:=load(context.temp_allocator)
    testing.expect(t,ok && len(mappings)==6)
    for mapping in mappings {
        rendered:=text(mappings,mapping.series,mapping.variant,context.temp_allocator)
        testing.expect(t,strings.has_prefix(rendered,mapping.label))
        for panel in mapping.panels {for section in panel.sections {
            testing.expect(t,section.gridColumns>0 && strings.contains(rendered,section.name))
            for module in section.modules {for value in ([5]string{module.webUi,module.tx,module.rx,module.canGwId,module.palkoPos}) {
                if value!="" {testing.expect(t,strings.contains(rendered,value) && strings.contains(describe(module,context.temp_allocator),value))}
            }}
        }}
    }
    testing.expect(t,strings.contains(text(mappings," slim100 "," ",context.temp_allocator),"1473"))
    testing.expect_value(t,text(mappings,"UFC150","missing",context.temp_allocator),"Unknown power module mapping: UFC150 missing")
    testing.expect_value(t,describe({webUi="1473",tx="0x5C1"},context.temp_allocator),"WEB UI: 1473, TX: 0x5C1")
}

@(test)
diagram_preserves_cabinet_rows_and_section_spans :: proc(t:^testing.T) {
    mappings,loaded:=load(context.temp_allocator)
    testing.expect(t,loaded && len(mappings)==6)
    counts:=[6]int{4,15,12,12,16,20}
    for mapping,index in mappings {
        narrow,valid:=diagram(mapping,8,20,80)
        wide,wide_valid:=diagram(mapping,8,20,1200)
        testing.expect(t,valid && wide_valid && narrow.module_count==counts[index] && wide.module_count==counts[index])
        testing.expect(t,narrow.width>80 && wide.width==1200 && narrow.height==wide.height)
        previous:Rect
        for card,at in narrow.modules[:narrow.module_count] {
            box:=card.box
            testing.expect(t,box.x>=16 && box.width>=22*8 && box.x+box.width<=narrow.width-16+0.01 && box.y+box.height<narrow.height)
            testing.expect(t,at==0 || box.y>previous.y || box.y==previous.y && box.x>=previous.x+previous.width)
            testing.expect_value(t,wide.modules[at].module,card.module)
            previous=box
        }
        for panel in narrow.panels[:narrow.panel_count] {testing.expect(t,panel.width==narrow.width && panel.height>0 && panel.y+panel.height<=narrow.height)}
    }
    mixed,found:=find(mappings," ufc150 ","100/50")
    testing.expect(t,found)
    layout,valid:=diagram(mixed,8,20,80)
    testing.expect(t,valid && layout.header_count==3 && layout.module_count==12)
    a,b,c:=layout.modules[0],layout.modules[1],layout.modules[2]
    testing.expect(t,a.box.y==b.box.y && b.box.y==c.box.y && a.box.x<b.box.x && b.box.x<c.box.x)
    testing.expect_value(t,a.module,mixed.panels[0].sections[0].modules[0])
    testing.expect_value(t,b.module,mixed.panels[0].sections[0].modules[1])
    testing.expect_value(t,c.module,mixed.panels[0].sections[1].modules[0])
    testing.expect(t,layout.headers[0].box.width==2*a.box.width+8 && layout.headers[1].box.width==c.box.width)
    // A valid 200,000-character table cell can measure wider than 1e6 pixels.
    huge,huge_valid:=diagram(mixed,8,20,200000*8)
    capped,capped_valid:=diagram(mixed,8,20,1e6)
    testing.expect(t,huge_valid && capped_valid && huge.width==1e6)
    testing.expect_value(t,huge,capped)
    _,valid=diagram(mixed,8,20,math.QNAN_F32);testing.expect(t,!valid)
    _,valid=diagram(mixed,8,20,math.INF_F32);testing.expect(t,!valid)
    _,valid=diagram(mixed,0,20,80);testing.expect(t,!valid)
    _,valid=diagram(mixed,8,20,-1);testing.expect(t,!valid)
    _,valid=diagram({},8,20,80);testing.expect(t,!valid)
}
