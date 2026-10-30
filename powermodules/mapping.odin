package powermodules

import "core:encoding/json"
import "core:mem"
import "core:strings"
import "core:fmt"

// Snapshot of Electrobun kb_powerModuleMappings.ts at
// 1fc06c6449b3eedef1e78ee585c5908728625ba0. Decode once per document;
// mappings and rendered strings belong to their supplied allocators.
Module :: struct {webUi,tx,rx,canGwId,palkoPos: string}
Module_Section :: struct {name:string,gridColumns:int,modules:[]Module}
Module_Panel :: struct {sections:[]Module_Section}
Module_Mapping :: struct {id,label,series,variant:string,panels:[]Module_Panel}
load :: proc(allocator:mem.Allocator)->([]Module_Mapping,bool) {
	rows:[]Module_Mapping
	error:=json.unmarshal(transmute([]u8)#load("power_modules.json"),&rows,allocator=allocator)
	if error!=nil {return nil,false}
	return rows,true
}
text :: proc(mappings:[]Module_Mapping,series,variant:string,allocator:mem.Allocator)->string {
	if len(mappings)==0 {return "Power module mappings unavailable."}
	for mapping in mappings {
		if !strings.equal_fold(strings.trim_space(series),mapping.series) || strings.trim_space(variant)!=mapping.variant {continue}
		builder:=strings.builder_make(allocator)
		strings.write_string(&builder,mapping.label)
		for panel in mapping.panels {
			strings.write_string(&builder,"\n")
			rows:=0
			for section in panel.sections {if section.gridColumns>0 {rows=max(rows,(len(section.modules)+section.gridColumns-1)/section.gridColumns);strings.write_string(&builder,fmt.tprintf("% -*s",section.gridColumns*22,section.name))}}
			strings.write_string(&builder,"\n")
			for row in 0..<rows {
				for field in 0..<5 {
				has_value:=false
				for section in panel.sections {for col in 0..<section.gridColumns {index:=row*section.gridColumns+col;if index<len(section.modules) {m:=section.modules[index];values:=[5]string{m.webUi,m.tx,m.rx,m.canGwId,m.palkoPos};has_value=has_value || values[field]!=""}}}
				if !has_value {continue}
					for section in panel.sections {for col in 0..<section.gridColumns {
						index:=row*section.gridColumns+col
						value:=""
						if index<len(section.modules) {m:=section.modules[index];values:=[5]string{m.webUi,m.tx,m.rx,m.canGwId,m.palkoPos};labels:=[5]string{"WEB UI","TX","RX","CAN GW ID","PALKO pos."};if values[field]!="" {value=fmt.tprintf("%s: %s",labels[field],values[field])}}
						strings.write_string(&builder,fmt.tprintf("% -22s",value))
					}}
					strings.write_string(&builder,"\n")
				}
				strings.write_string(&builder,"\n")
			}
		}
		return strings.to_string(builder)
	}
	return fmt.aprintf("Unknown power module mapping: %s %s",series,variant,allocator=allocator)
}
