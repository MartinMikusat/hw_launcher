# hw_launcher rewrite plan

## Locked decisions

| Decision | Choice |
|---|---|
| Product shape | Standalone macOS menu-bar agent launcher |
| UI implementation | Odin with `hw_odin_ui_framework` |
| Agent implementation | Separate Odin `hw_agent` process |
| Process boundary | JSONL over child stdin/stdout; no HTTP listener or port |
| Lifecycle | Start on first prompt, retain while the launcher runs, terminate on quit |
| Session storage | Backend-owned JSONL files |
| Pre-rewrite source | Removed from `main`; preserved at `a7ac0b2`, release `0.1.2` |

## Existing backend research

`../hw_agent` already contains the intended implementation. Its original
agent-harness commit is `af1a547`:

- provider-neutral agent event model and bounded turn loop;
- OpenAI-compatible streaming with tool-call assembly;
- local bash/read/write/edit tools; loop results are capped at 30,000 characters;
- cancellation, steering, follow-up messages, and abort;
- JSONL session persistence and context compaction;
- JSONL stdio RPC with `prompt`, `steer`, `follow_up`, `abort`, and `quit`.

Do not reimplement these packages in the launcher. Close the remaining backend
gaps in `hw_agent`: wire a real tool permission policy and make abort interrupt
a running shell child.

## Work order

1. Add a buildable Odin macOS application skeleton with a menu-bar status item,
   global hotkey, borderless floating panel, and custom-rendered text UI.
2. Add a bounded process supervisor that launches `hw_agent -rpc`, writes one
   JSON command per line, and parses one event per line.
3. Map backend events into authoritative launcher state: prompt, streaming
   assistant text, tool start/end, completion, error, and abort.
4. Add session selection and explicit model/provider configuration only after
   the basic prompt-to-completion path works.
5. Package and sign the Odin app and establish a new release feed.

## Non-goals

- No compatibility client for another coding-agent runtime.
- No TCP server, service discovery, daemon registry, or remote execution API.
- No plugin system, multi-agent orchestration, or MCP layer before the core
  launcher path is useful.

## Acceptance

- The app builds through `hw-odin` on Apple Silicon.
- The panel and transcript are rendered by the Odin UI stack.
- A prompt streams assistant text and tool lifecycle events from `hw_agent`.
- Abort reaches the backend and terminates an in-flight shell child.
- Quit terminates the backend child and preserves its JSONL session.
- The process opens no listening network socket.
