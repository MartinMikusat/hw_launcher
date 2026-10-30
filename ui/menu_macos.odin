package delta_ui

import "base:intrinsics"
import "core:fmt"
import NS "core:sys/darwin/Foundation"
import coretext "ui_framework:coretext"

native_menu_string :: proc(text: string) -> ^NS.String {
    return intrinsics.objc_send(^NS.String, (^NS.Object)(rawptr(coretext.cfstring(text))), "autorelease")
}

// The system menu bar exposes OS actions; application content remains in Clay.
native_menu_create :: proc(title: string, settings_action, close_action: cstring) -> ^NS.Menu {
	bar := NS.Menu.alloc()->initWithTitle(native_menu_string(title))
	for title in ([3]string{title, "Edit", "Window"}) {
		name := native_menu_string(title)
		menu := NS.Menu.alloc()->initWithTitle(name)
		item := bar->addItemWithTitle(name, nil, NS.AT(""))
		item->setSubmenu(menu)
		menu->release()
	}
	app := bar->itemAtIndex(0)->submenu()
	app->addItemWithTitle(native_menu_string(fmt.tprintf("About %s", title)), NS.sel_registerName("orderFrontStandardAboutPanel:"), NS.AT(""))
	app->addItem(NS.MenuItem.separatorItem())
	app->addItemWithTitle(NS.AT("Settings..."), NS.sel_registerName(settings_action), NS.AT(","))
	app->addItem(NS.MenuItem.separatorItem())
	app->addItemWithTitle(native_menu_string(fmt.tprintf("Hide %s", title)), NS.sel_registerName("hide:"), NS.AT("h"))
	app->addItemWithTitle(NS.AT("Hide Others"), NS.sel_registerName("hideOtherApplications:"), NS.AT("h"))->setKeyEquivalentModifierMask({.Command, .Option})
	app->addItemWithTitle(NS.AT("Show All"), NS.sel_registerName("unhideAllApplications:"), NS.AT(""))
	app->addItem(NS.MenuItem.separatorItem())
	app->addItemWithTitle(native_menu_string(fmt.tprintf("Quit %s", title)), NS.sel_registerName("terminate:"), NS.AT("q"))
	edit := bar->itemAtIndex(1)->submenu()
	for action in ([4]struct {title, key: string, selector: cstring}{
		{"Cut", "x", "cut:"}, {"Copy", "c", "copy:"}, {"Paste", "v", "paste:"}, {"Select All", "a", "selectAll:"},
	}) {
		title, key := native_menu_string(action.title), native_menu_string(action.key)
		edit->addItemWithTitle(title, NS.sel_registerName(action.selector), key)
	}
	window := bar->itemAtIndex(2)->submenu()
	window->addItemWithTitle(NS.AT("Minimize"), NS.sel_registerName("performMiniaturize:"), NS.AT("m"))
	window->addItemWithTitle(NS.AT("Zoom"), NS.sel_registerName("performZoom:"), NS.AT(""))
	window->addItemWithTitle(NS.AT("Enter Full Screen"), NS.sel_registerName("toggleFullScreen:"), NS.AT("f"))->setKeyEquivalentModifierMask({.Command, .Control})
	window->addItem(NS.MenuItem.separatorItem())
	window->addItemWithTitle(NS.AT("Close"), NS.sel_registerName(close_action), NS.AT("w"))
	return bar
}
