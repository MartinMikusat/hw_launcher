package launcher

import "base:runtime"
import "core:fmt"

Event_Type_Spec :: struct {
	class_name: u32,
	event_kind: u32,
}

foreign import carbon "system:Carbon.framework"
foreign carbon {
	GetApplicationEventTarget :: proc "c" () -> rawptr ---
	InstallEventHandler :: proc "c" (
		target: rawptr,
		handler: rawptr,
		type_count: u32,
		types: ^Event_Type_Spec,
		user_data: rawptr,
		handler_ref: ^rawptr,
	) -> i32 ---
	RemoveEventHandler :: proc "c" (handler_ref: rawptr) -> i32 ---
	RegisterEventHotKey :: proc "c" (
		key_code: u32,
		modifiers: u32,
		hotkey_id: u32,
		target: rawptr,
		options: u32,
		hotkey_ref: ^rawptr,
	) -> i32 ---
	UnregisterEventHotKey :: proc "c" (hotkey_ref: rawptr) -> i32 ---
}

HOTKEY_EVENT_CLASS :: u32(0x6B657962)
HOTKEY_EVENT_KIND :: u32(5)
HOTKEY_ID :: u32(0x48574C52)
HOTKEY_KEY_GRAVE :: u32(50)
HOTKEY_MODIFIER_OPTION :: u32(0x2000)

Global_Hotkey :: struct {
	handler_ref: rawptr,
	hotkey_ref:  rawptr,
}

global_hotkey: Global_Hotkey

launcher_hotkey_event :: proc "c" (next_handler: rawptr, event: rawptr, user_data: rawptr) -> i32 {
	context = runtime.default_context()
	panel_toggle()
	return 0
}

global_hotkey_start :: proc() -> string {
	if global_hotkey.hotkey_ref != nil {return ""}
	types := [1]Event_Type_Spec{{HOTKEY_EVENT_CLASS, HOTKEY_EVENT_KIND}}
	install_status := InstallEventHandler(
		GetApplicationEventTarget(),
		rawptr(launcher_hotkey_event),
		1,
		&types[0],
		nil,
		&global_hotkey.handler_ref,
	)
	if install_status != 0 {
		global_hotkey.handler_ref = nil
		return fmt.tprintf("Could not install the global hotkey handler (%d).", install_status)
	}
	register_status := RegisterEventHotKey(
		HOTKEY_KEY_GRAVE,
		HOTKEY_MODIFIER_OPTION,
		HOTKEY_ID,
		nil,
		0,
		&global_hotkey.hotkey_ref,
	)
	if register_status != 0 {
		_ = RemoveEventHandler(global_hotkey.handler_ref)
		global_hotkey.handler_ref = nil
		global_hotkey.hotkey_ref = nil
		return fmt.tprintf("Could not register Option+` (%d).", register_status)
	}
	return ""
}

global_hotkey_stop :: proc() {
	if global_hotkey.hotkey_ref != nil {
		_ = UnregisterEventHotKey(global_hotkey.hotkey_ref)
		global_hotkey.hotkey_ref = nil
	}
	if global_hotkey.handler_ref != nil {
		_ = RemoveEventHandler(global_hotkey.handler_ref)
		global_hotkey.handler_ref = nil
	}
}
