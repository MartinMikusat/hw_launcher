# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Odin on macOS, using the shared `hw_odin_ui_framework` and `hw_clay` libraries.
The agent runtime is the separate `hw_agent` executable, owned as a child process
and controlled through newline-delimited JSON over stdin/stdout.

## Users

A developer or operator invoking a focused local task from anywhere on macOS.
The primary job is to open a keyboard-first launcher, describe the task, watch
the agent work, and return to the previous application.

## Product Purpose

`hw_launcher` provides immediate access to a local coding agent without opening
a terminal or choosing a project first. Success means a useful task can be
started in seconds, progress is legible at a glance, and the launcher remains
out of the way afterward.

## Positioning

A transient command surface for one focused task at a time, rather than a
long-lived IDE, terminal emulator, or session browser.

## Operating Context

- macOS desktop; Apple Silicon is the primary target.
- A global hotkey opens and hides the launcher.
- The backend starts in the user's home directory and selects paths per task.
- The same conversation remains available while the launcher process stays
  alive; panel hiding does not end the task.
- Local tools run automatically in this first product version.

## Capabilities and Constraints

- One focused conversation with prompt submission, streaming assistant text,
  visible tool activity, errors, completion, and abort.
- One supervised backend child using JSONL stdio; no TCP server or port.
- The floating panel is custom-rendered and keyboard-first.
- The first version does not include a directory picker, session browser, remote
  execution API, plugin system, or multi-agent orchestration.
- Tool actions are automatic; the operator accepts that trust boundary for the
  first version.

## Brand Commitments

- Project name: `hw_launcher`.
- The UI inherits Delta Support's strict terminal styling: one regular
  monospaced face, restrained neutral surfaces, bracketed controls, semantic
  state colors, and no decorative card treatment.
- The product should feel immediate, quiet, and operational rather than like a
  conventional chat app.

## Evidence on Hand

- The working agent loop, tools, sessions, compaction, and JSONL RPC live in
  `/Users/martin/projects/hw_agent`.
- Delta Support's native terminal style is documented in
  `/Users/martin/projects/hw_delta_support/DESIGN.md`.
- Calendar and Clips provide current Odin macOS application, Metal, input, and
  lifecycle patterns.
- No screenshots, user testimonials, or performance claims exist for this new
  launcher surface yet; future work must not fabricate them.

## Product Principles

- Open, act, and disappear in seconds.
- Keep one authoritative transcript and one backend conversation.
- Make system and tool activity visible without turning the panel into a log
  viewer.
- Prefer the smallest reliable interaction that preserves operator control.
- Match the established Delta Support terminal language rather than inventing
  a second macOS visual system.

## Accessibility & Inclusion

The launcher is operable entirely by keyboard. Focus and selection use strong
foreground/background inversion, text remains selectable where practical, and
status is communicated by text rather than color alone.
