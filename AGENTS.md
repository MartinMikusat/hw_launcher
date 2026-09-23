# hw_launcher

Native macOS launcher with a Spotlight-style floating panel on a global hotkey.
The UI and agent client are Odin; the agent runtime remains the separate
`../hw_agent` executable.

## Commands

- `./build.sh [debug|release]` — build `build/hw_launcher`
- `./test.sh` — run all Odin tests
- `./build/hw_launcher --offscreen build/frames/launcher.ppm --theme=light|dark` —
  render the panel without opening a window
- `OPENROUTER_API_KEY=... ../hw_agent/build/hw_agent -rpc` — direct backend
  protocol smoke; the launcher inherits the same environment

`HW_AGENT_BIN` overrides the sibling `../hw_agent/build/hw_agent` path during
development.

## Architecture

- `main.odin` — windowed and offscreen entry points
- `host.odin` — AppKit status item, square nonactivating panel, Metal layer,
  display-link clock, pointer and wheel delivery
- `hotkey.odin` — Carbon `Option+\`` global hotkey
- `view.odin` — Delta Support terminal primitives, Clay layout, draw dispatch
- `input.odin` — shared UTF-8 editor state, selection, clipboard, and IME
- `state.odin` — authoritative bounded transcript and launcher state
- `backend_protocol.odin` — JSONL command/event contract and event application
- `backend.odin` — one child process, bounded reader, diagnostics, and shutdown
- `offscreen.odin` — noninteractive Metal/PPM inspection surface

The backend child starts on the first prompt, remains available while hidden or
busy, and terminates when the launcher exits. The panel never opens a listening
socket. There is one authoritative transcript; the backend never mutates UI
state directly.

## Style

`DESIGN.md` is the visual authority. The implementation deliberately consumes
`delta_support:ui` for the embedded Iosevka face, 13 logical-pixel text, 1.2
line height, themes, terminal input, and semantic colors. Do not introduce
proportional text, rounded panels, shadows, chat bubbles, cards, sidebars, or
local copies of those primitives.

## Verification

- `hw-odin test` and both debug/release builds are correctness gates.
- Keep tests headless. Never launch or drive the app through synthetic UI input.
- Render light and dark offscreen frames after UI changes and inspect the PNGs.
- Manual status-item, hotkey, IME, clipboard, live backend, and window-resign
  checks belong to the operator.
