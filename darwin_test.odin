package launcher

import "core:strings"
import "core:testing"

@(test)
nsstring_does_not_clear_unrelated_temp_memory :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	if !testing.expect(t, objc_initialize(), "Objective-C initialization failed") {return}
	sentinel := strings.clone("sentinel", context.temp_allocator)
	value := nsstring("value")
	testing.expect(t, value != nil, "NSString creation failed")
	testing.expect_value(t, sentinel, "sentinel")
}
