# hw_launcher interface

`hw_launcher` uses Delta Support's strict terminal system without adding a
second visual language.

## Foundation

- Use embedded Iosevka Regular at 13 logical pixels for every label, message,
  status, tool receipt, and input.
- Use one 1.2 line height everywhere. Hierarchy comes from placement, grouping,
  and semantic color, never weight or size changes.
- Light background is `#F9F8F6` with `#2E2E2E` foreground. Dark background is
  `#171717` with `#D1D1D1` foreground.
- Use flat square surfaces: no radius, shadow, tint, gradient, or decorative
  outline.
- Use lime `#BEF263` with black text only for confirmed success, red for
  failure, orange for working/warning, and theme blue for the initial operating
  notice or copyable state.

## Layout

The default panel is 760×520 points and centers in the active screen's visible
frame. Its entire layout is one vertical column with a 1ch outer inset:

1. one fixed status row;
2. one growing scrollback region with one blank row above its first entry;
3. one fixed terminal input row.

The status row reads `hw_launcher  model  state`. It uses ordinary foreground
and clips rather than truncating the model into another column. `[Abort]`
appears only while the backend is starting or working and uses the shared
foreground/background inversion.

There is no sidebar, card, toolbar, avatar, bubble, or secondary navigation.

## Scrollback

- User text begins with a fixed `>` prompt and wraps in the remaining width.
- Assistant text is ordinary foreground and wraps directly into the
  chronological stream.
- Tool activity is one clipped terminal row: `$ name`, output or arguments, and
  a right-aligned `[working]`, `[ok]`, or `[error]` state.
- Errors wrap in danger red. Operational notices use theme blue only when they
  communicate a meaningful state rather than decoration.
- New events follow the tail. Pointer or trackpad scrolling takes control and
  remains there until another event arrives.
- The transcript is bounded to 500 entries. Assistant text is bounded to 1 MiB;
  displayed tool output is bounded to 64 KiB.

## Input

The bottom row uses Delta Support's terminal input primitive: a fixed `>` in the
first character cell, the editable value immediately after it, gray placeholder
text while empty, and a one-logical-pixel caret at the insertion point. The
value is limited to 16 KiB. It supports selection, clipboard, native IME
marking, Enter submission, Tab insertion, Escape hide, and Command-Q quit.

While the backend is busy, Enter sends `steer`; otherwise it sends `prompt`.
Submitting an empty value does nothing.

## States and motion

The initial state is `Ready at ~. Local tools run automatically.` This makes the
automatic-tool trust boundary explicit without adding onboarding chrome.

The panel appears and disappears instantly. Its display link is paused whenever
no input, scroll, backend event, or caret blink needs a frame. There are no
entrance, exit, hover, or decorative animations.

## Accessibility

Keyboard operation is mandatory. Focus and hover use full inversion, semantic
states always include text, and the input retains a real editable value rather
than treating its placeholder as content. Native text-input methods own
selection, clipboard, and IME geometry. A native accessibility bridge exposes
status, transcript, input, and Abort without introducing a native content view
hierarchy.
