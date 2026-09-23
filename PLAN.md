# hw_launcher implementation plan

## Locked decisions

| Decision | Choice |
|---|---|
| Product shape | Standalone macOS menu-bar agent launcher |
| UI implementation | Odin with `hw_clay` and `hw_odin_ui_framework` |
| Visual system | Delta Support terminal primitives |
| Agent implementation | Separate Odin `hw_agent` process |
| Process boundary | JSONL over child stdin/stdout; no HTTP listener or port |
| Lifecycle | Start on first prompt, retain while the launcher runs, terminate on quit |
| Session storage | In-memory launcher transcript; backend process owns agent context |
| First-version job | One focused task with steering while busy |
| Tool policy | Local tools run automatically |

## Completed

- Buildable Odin menu-bar application with `Option+\`` hotkey.
- Square nonactivating 760×520 panel rendered through Clay, CoreText, and Metal.
- Delta Support light/dark terminal styling with one font and line height.
- Bounded chronological transcript for user, assistant, tool, notice, and error
  events.
- Shared UTF-8 editor with selection, pointer placement, clipboard, and IME.
- Supervised `hw_agent -rpc` child with bounded JSONL reads, automatic tool
  execution, steering, abort, diagnostics, and clean shutdown.
- Headless protocol/state/layout tests and light/dark offscreen renders.

## Next verification

1. Operator launches the built binary and verifies the status item and global
   hotkey on a real desktop session.
2. Operator verifies focus, IME, clipboard, Escape hide, window-resign hide, and
   Command-Q.
3. Run one cheap live `hw_agent` task and verify prompt, stream, tool receipt,
   completion, notification-free hide/resume, and abort.
4. Package and sign the first Odin `.app` only after the manual window path is
   accepted.
