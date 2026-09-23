package launcher

import "core:dynlib"
import "core:strings"

Id :: rawptr
Sel :: rawptr

Point :: struct {x, y: f64}
Size :: struct {width, height: f64}
Rect :: struct {origin: Point, size: Size}

foreign import dispatch "system:System"
foreign dispatch {
	dispatch_async_f  :: proc(queue: rawptr, ctx: rawptr, work: proc "c" (rawptr)) ---
	_dispatch_main_q: Dispatch_Queue_Storage
}

Dispatch_Queue_Storage :: struct {_opaque: u8}

foreign import objc_runtime "system:Foundation.framework"
foreign objc_runtime {
	objc_getClass          :: proc "c" (name: cstring) -> Id ---
	objc_getProtocol       :: proc "c" (name: cstring) -> Id ---
	objc_allocateClassPair :: proc "c" (superclass: Id, name: cstring, extra: uint) -> Id ---
	objc_registerClassPair :: proc "c" (cls: Id) ---
	class_addMethod        :: proc "c" (cls: Id, name: Sel, imp: rawptr, types: cstring) -> bool ---
	class_addProtocol      :: proc "c" (cls: Id, protocol: Id) -> bool ---
	class_getSuperclass    :: proc "c" (cls: Id) -> Id ---
	sel_registerName       :: proc "c" (name: cstring) -> Sel ---
}

objc_send_address: rawptr

objc_initialize :: proc() -> bool {
	if objc_send_address != nil {return true}
	handle, loaded := dynlib.load_library("/usr/lib/libobjc.A.dylib")
	if !loaded {return false}
	objc_send_address, loaded = dynlib.symbol_address(handle, "objc_msgSend")
	return loaded
}

msg_id0 :: proc(receiver: Id, selector: Sel) -> Id {
	send := transmute(proc "c" (Id, Sel) -> Id)objc_send_address
	return send(receiver, selector)
}

msg_id_id :: proc(receiver: Id, selector: Sel, argument: Id) -> Id {
	send := transmute(proc "c" (Id, Sel, Id) -> Id)objc_send_address
	return send(receiver, selector, argument)
}

msg_id_f64 :: proc(receiver: Id, selector: Sel, value: f64) -> Id {
	send := transmute(proc "c" (Id, Sel, f64) -> Id)objc_send_address
	return send(receiver, selector, value)
}

msg_id_u_u_u_bool :: proc(
	receiver: Id,
	selector: Sel,
	first, second, third: uint,
	fourth: bool,
) -> Id {
	send := transmute(proc "c" (Id, Sel, uint, uint, uint, bool) -> Id)objc_send_address
	return send(receiver, selector, first, second, third, fourth)
}

msg_f64_0 :: proc(receiver: Id, selector: Sel) -> f64 {
	send := transmute(proc "c" (Id, Sel) -> f64)objc_send_address
	return send(receiver, selector)
}

msg_id_rect :: proc(receiver: Id, selector: Sel, value: Rect) -> Id {
	send := transmute(proc "c" (Id, Sel, Rect) -> Id)objc_send_address
	return send(receiver, selector, value)
}

msg_id_rect_u_u_i :: proc(
	receiver: Id,
	selector: Sel,
	value: Rect,
	first, second: uint,
	third: int,
) -> Id {
	send := transmute(proc "c" (Id, Sel, Rect, uint, uint, int) -> Id)objc_send_address
	return send(receiver, selector, value, first, second, third)
}

msg_bool_id :: proc(receiver: Id, selector: Sel, argument: Id) -> bool {
	send := transmute(proc "c" (Id, Sel, Id) -> bool)objc_send_address
	return send(receiver, selector, argument)
}

msg_bool_id_id :: proc(receiver: Id, selector: Sel, first, second: Id) -> bool {
	send := transmute(proc "c" (Id, Sel, Id, Id) -> bool)objc_send_address
	return send(receiver, selector, first, second)
}

msg_void0 :: proc(receiver: Id, selector: Sel) {
	send := transmute(proc "c" (Id, Sel))objc_send_address
	send(receiver, selector)
}

msg_void_id :: proc(receiver: Id, selector: Sel, argument: Id) {
	send := transmute(proc "c" (Id, Sel, Id))objc_send_address
	send(receiver, selector, argument)
}

msg_void_i :: proc(receiver: Id, selector: Sel, value: int) {
	send := transmute(proc "c" (Id, Sel, int))objc_send_address
	send(receiver, selector, value)
}

msg_void_u :: proc(receiver: Id, selector: Sel, value: uint) {
	send := transmute(proc "c" (Id, Sel, uint))objc_send_address
	send(receiver, selector, value)
}

msg_void_sel :: proc(receiver: Id, selector: Sel, value: Sel) {
	send := transmute(proc "c" (Id, Sel, Sel))objc_send_address
	send(receiver, selector, value)
}

msg_void_bool :: proc(receiver: Id, selector: Sel, value: bool) {
	send := transmute(proc "c" (Id, Sel, bool))objc_send_address
	send(receiver, selector, value)
}

msg_rect_0 :: proc(receiver: Id, selector: Sel) -> Rect {
	send := transmute(proc "c" (Id, Sel) -> Rect)objc_send_address
	return send(receiver, selector)
}

msg_rect_rect :: proc(receiver: Id, selector: Sel, value: Rect) -> Rect {
	send := transmute(proc "c" (Id, Sel, Rect) -> Rect)objc_send_address
	return send(receiver, selector, value)
}

msg_rect_rect_id :: proc(receiver: Id, selector: Sel, value: Rect, view: Id) -> Rect {
	send := transmute(proc "c" (Id, Sel, Rect, Id) -> Rect)objc_send_address
	return send(receiver, selector, value, view)
}

msg_void_rect :: proc(receiver: Id, selector: Sel, value: Rect) {
	send := transmute(proc "c" (Id, Sel, Rect))objc_send_address
	send(receiver, selector, value)
}

msg_void_rect_bool :: proc(receiver: Id, selector: Sel, value: Rect, display: bool) {
	send := transmute(proc "c" (Id, Sel, Rect, bool))objc_send_address
	send(receiver, selector, value, display)
}

nsstring :: proc(value: string) -> Id {
	if len(value) == 0 {return msg_id0(objc_getClass("NSString"), sel_registerName("string"))}
	c_value := strings.clone_to_cstring(value, context.temp_allocator)
	send := transmute(proc "c" (Id, Sel, cstring) -> Id)objc_send_address
	return send(objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), c_value)
}

nsstring_to_string :: proc(value: Id) -> string {
	if value == nil {return ""}
	send := transmute(proc "c" (Id, Sel) -> cstring)objc_send_address
	c_value := send(value, sel_registerName("UTF8String"))
	if c_value == nil {return ""}
	return string(c_value)
}

ns_range :: struct {location, length: uint}
