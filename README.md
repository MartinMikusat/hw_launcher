# hw_launcher

Native macOS hotkey launcher for one focused local agent task. The interface is
Odin with Delta Support's terminal styling; the agent loop is the separate Odin
`hw_agent` executable, supervised over newline-delimited JSON on stdio.

## Build and test

```sh
./build.sh debug
./test.sh
```

The debug binary is `build/hw_launcher`.
Tests run headlessly and fail on tracked leaks or invalid frees.

## Backend

The default backend path is `../hw_agent/build/hw_agent`. Override it with
`HW_AGENT_BIN`. The child inherits `OPENROUTER_API_KEY` and starts in `$HOME`.

## Offscreen inspection

```sh
./build/hw_launcher --offscreen build/frames/launcher-dark.ppm --theme=dark
sips -s format png build/frames/launcher-dark.ppm \
  --out build/frames/launcher-dark.png
```

This path renders Metal frames without opening a window or driving UI input.

## Manual acceptance

- Toggle with Option+` and the status item; hide with Escape and by changing
  focus. Repeat after the app has been open for a while.
- Type, move the caret, delete, submit, and use Tab. Click, double-click, and drag
  to select; copy, cut, paste, and select all. Leave the caret idle for several
  blinks, then hide and reopen.
- Compose Japanese or Chinese, replace a selection containing emoji, and confirm
  candidate windows appear at the caret, including with horizontally scrolled text.
- Stream enough output to fill scrollback with the pointer over the input. Check
  tail following, manual scrolling, and steering without duplicate user messages.
- Abort through Command-period, a click, and VoiceOver. Dragging from elsewhere
  onto Abort or releasing outside it must not activate it. Check VoiceOver status,
  newest transcript, prompt values, and element positions.
- Stop the backend during a tool call and retry. Quit while it is busy and confirm
  the launcher's backend child exits. A failed backend launch must leave a readable
  error and allow retry.
