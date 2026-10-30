package delta_ui

import text_input "components:text_input"

// AppKit selector translation; the shared editor owns all text mutations.
edit_command :: proc(state: ^text_input.State, target: ^string, name: string) -> bool {
	assert(state != nil && target != nil)
	switch name {
	case "moveLeft:": text_input.move_left(state, target^, false)
	case "moveRight:": text_input.move_right(state, target^, false)
	case "moveLeftAndModifySelection:": text_input.move_left(state, target^, true)
	case "moveRightAndModifySelection:": text_input.move_right(state, target^, true)
	case "moveWordLeft:": text_input.move_word_left(state, target^, false)
	case "moveWordRight:": text_input.move_word_right(state, target^, false)
	case "moveWordLeftAndModifySelection:": text_input.move_word_left(state, target^, true)
	case "moveWordRightAndModifySelection:": text_input.move_word_right(state, target^, true)
	case "moveToBeginningOfLine:", "moveToBeginningOfDocument:", "moveUp:": text_input.move_line_start(state, target^, false)
	case "moveToEndOfLine:", "moveToEndOfDocument:", "moveDown:": text_input.move_line_end(state, target^, false)
	case "moveToBeginningOfLineAndModifySelection:", "moveToBeginningOfDocumentAndModifySelection:", "moveUpAndModifySelection:": text_input.move_line_start(state, target^, true)
	case "moveToEndOfLineAndModifySelection:", "moveToEndOfDocumentAndModifySelection:", "moveDownAndModifySelection:": text_input.move_line_end(state, target^, true)
	case "deleteBackward:": text_input.delete_backward(state, target)
	case "deleteForward:": text_input.delete_forward(state, target)
	case "deleteWordBackward:": text_input.delete_word_backward(state, target)
	case "deleteWordForward:":
		if !text_input.has_selection(state, target^) {text_input.move_word_right(state, target^, true)}
		text_input.remove_selection(state, target)
	case "deleteToBeginningOfLine:":
		text_input.move_line_start(state, target^, true)
		text_input.remove_selection(state, target)
	case "deleteToEndOfLine:":
		text_input.move_line_end(state, target^, true)
		text_input.remove_selection(state, target)
	case "selectAll:": text_input.set_selection(state, target^, 0, len(target^))
	case: return false
	}
	return true
}
