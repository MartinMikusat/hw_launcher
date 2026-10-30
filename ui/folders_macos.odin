package delta_ui

import "base:intrinsics"
import "core:strings"
import NS "core:sys/darwin/Foundation"

folder_native_text :: proc(value: NS.id) -> string {
 if value==nil {return ""}
 return string(intrinsics.objc_send(cstring,(^NS.Object)(rawptr(value)),"UTF8String"))
}

choose_folder :: proc() -> (string, bool) {
    return choose_open_path(false)
}
choose_open_file :: proc() -> (string, bool) {
    return choose_open_path(true)
}
@(private="file")
choose_open_path :: proc(file:bool) -> (string, bool) {
	when #config(HW_DELTA_TEST_MODE, bool(false)) {return "", false}
	panel := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(intrinsics.objc_find_class("NSOpenPanel"))), "openPanel")
	if panel == nil {return "", false}
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setCanChooseFiles:", file)
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setCanChooseDirectories:", bool(!file))
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setCanCreateDirectories:", bool(!file))
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setAllowsMultipleSelection:", bool(false))
	if intrinsics.objc_send(int, (^NS.Object)(rawptr(panel)), "runModal") != 1 {return "", false}
	url := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(panel)), "URL")
	path := folder_native_text(intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(url)), "path"))
    owned,error:=strings.clone(path)
    return owned,error==nil && owned!=""
}

open_folder :: proc(path: string) -> bool {
	when #config(HW_DELTA_TEST_MODE, bool(false)) {return false}
	workspace := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(intrinsics.objc_find_class("NSWorkspace"))), "sharedWorkspace")
	url := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(intrinsics.objc_find_class("NSURL"))), "fileURLWithPath:", native_menu_string(path))
	return intrinsics.objc_send(bool, (^NS.Object)(rawptr(workspace)), "openURL:", url)
}

choose_save_file :: proc(suggested_name: string) -> (string, bool) {
	when #config(HW_DELTA_TEST_MODE, bool(false)) {return "", false}
	panel := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(intrinsics.objc_find_class("NSSavePanel"))), "savePanel")
	if panel == nil {return "", false}
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setCanCreateDirectories:", bool(true))
	intrinsics.objc_send(nil, (^NS.Object)(rawptr(panel)), "setNameFieldStringValue:", native_menu_string(suggested_name))
	if intrinsics.objc_send(int, (^NS.Object)(rawptr(panel)), "runModal") != 1 {return "", false}
	url := intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(panel)), "URL")
	path := folder_native_text(intrinsics.objc_send(NS.id, (^NS.Object)(rawptr(url)), "path"))
    owned,error:=strings.clone(path)
    return owned,error==nil && owned!=""
}
