package launcher

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import delta_settings "delta_support:settings"

run_offscreen :: proc() -> bool {
	if len(os.args) < 3 || os.args[1] != "--offscreen" {return false}
	path := os.args[2]
	width := 760
	height := 520
	scale := f32(2)
	theme := delta_settings.Theme.Dark
	for argument in os.args[3:] {
		switch {
		case strings.has_prefix(argument, "--width="):
			parsed, ok := strconv.parse_int(strings.trim_prefix(argument, "--width="))
			if !ok || parsed <= 0 {return false}
			width = parsed
		case strings.has_prefix(argument, "--height="):
			parsed, ok := strconv.parse_int(strings.trim_prefix(argument, "--height="))
			if !ok || parsed <= 0 {return false}
			height = parsed
		case strings.has_prefix(argument, "--scale="):
			parsed, ok := strconv.parse_f32(strings.trim_prefix(argument, "--scale="))
			if !ok || parsed <= 0 {return false}
			scale = parsed
		case argument == "--theme=light":
			theme = .Light
		case argument == "--theme=dark":
			theme = .Dark
		case:
			return false
		}
	}
	if directory := filepath.dir(path); len(directory) > 0 {
		_ = os.make_directory_all(directory)
	}
	if !render_offscreen(path, width, height, scale, theme) {return false}
	fmt.printf("wrote %s (%dx%d, scale %.1f)\n", path, width, height, scale)
	return true
}

main :: proc() {
	if len(os.args) > 1 {
		if os.args[1] == "--offscreen" {
			if !run_offscreen() {
				fmt.eprintln("usage: hw_launcher --offscreen <path.ppm> [--width=N] [--height=N] [--scale=N] [--theme=light|dark]")
				os.exit(2)
			}
			return
		}
		fmt.eprintln("usage: hw_launcher [--offscreen <path.ppm>]")
		os.exit(2)
	}
	if !objc_initialize() {
		fmt.eprintln("[hw_launcher] Objective-C runtime initialization failed")
		return
	}
	launcher_state_init(&launcher)
	backend_init()
	defer launcher_shutdown()

	if !panel_init() {
		fmt.eprintln("[hw_launcher] window or Metal initialization failed")
		return
	}

	if message := global_hotkey_start(); len(message) > 0 {
		transcript_append(&launcher.transcript, .Error, message)
		panel_show()
	}
	panel_run()
}

launcher_shutdown :: proc() {
	global_hotkey_stop()
	backend_destroy(&launcher)
	panel_shutdown()
	launcher_state_destroy(&launcher)
}
