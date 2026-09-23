# hw_launcher

Native macOS launcher with a Spotlight-style floating panel on a global hotkey.
The implementation is Odin.

## Architecture

The launcher owns the window, hotkey, transcript, input, and child-process
lifecycle. The agent loop stays in the separate `../hw_agent` repository and is
used as one long-lived child process over newline-delimited JSON on stdin/stdout.
There is no TCP server or port.

```text
global hotkey -> Odin launcher UI -> hw_agent -rpc -> provider + local tools
```

The backend owns provider streaming, tool execution, cancellation, JSONL
sessions, and context compaction. The launcher translates RPC events into UI
state and sends prompt, steer, follow-up, and abort commands.

Use `hw_odin_ui_framework` for rendering and native AppKit only for the window,
status item, global hotkey, and event delivery.

## Current state

The pre-rewrite application was removed from `main`; its final source is commit
`a7ac0b2` and its last release is `0.1.2`. The repository is intentionally
between implementations until the first buildable Odin application skeleton is
committed. Do not restore the deleted implementation or add a compatibility
layer for it.

## Commands

All Odin compiler commands must run through `hw-odin`. Add permanent launcher
commands when the application skeleton lands.

## Verification

- Build the Odin application through `hw-odin`.
- Test JSONL parsing and process lifecycle without driving the UI.
- Verify one backend child, ordered events, prompt completion, abort, and clean
  child shutdown.
- Keep manual UI interaction with the operator.
