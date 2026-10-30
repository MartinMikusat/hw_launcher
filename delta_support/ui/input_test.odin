package delta_ui

import "core:strings"
import "core:testing"
import text_input "components:text_input"

@(test)
file_panels_are_disabled_in_test_mode :: proc(t:^testing.T) {
    when #config(HW_DELTA_TEST_MODE,false) {
        file,chosen:=choose_open_file();testing.expect(t,file=="" && !chosen)
        folder,opened:=choose_folder();testing.expect(t,folder=="" && !opened)
        target,saved:=choose_save_file("fixture.txt");testing.expect(t,target=="" && !saved)
    }
}

@(test)
editing_selectors_use_shared_utf8_editor :: proc(t:^testing.T) {
	text:=strings.clone("Åsa café")
	defer delete(text)
	state:text_input.State
	text_input.focus(&state,1,text)
	testing.expect(t,edit_command(&state,&text,"moveWordLeftAndModifySelection:"))
	testing.expect_value(t,text_input.selected_text(&state,text),"café")
	testing.expect(t,edit_command(&state,&text,"deleteBackward:"))
	testing.expect_value(t,text,"Åsa ")
	testing.expect(t,edit_command(&state,&text,"moveToBeginningOfLine:"))
	testing.expect(t,edit_command(&state,&text,"deleteForward:"))
	testing.expect_value(t,text,"sa ")
	testing.expect(t,!edit_command(&state,&text,"unsupported:"))
	testing.expect(t,edit_command(&state,&text,"selectAll:"))
	testing.expect_value(t,text_input.selected_text(&state,text),"sa ")
}
