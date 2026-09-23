---
version: 1
slug: "main-odin"
primary_target: "main.odin"
related_targets: []
---

# Launcher panel

Mode: Operate. Audience: a developer invoking one focused local task. The
surface must open from a global hotkey, present one authoritative conversation,
and disappear after use. It inherits Delta Support's terminal identity and uses
`../hw_agent` over JSONL stdio. The first version has no directory picker,
session browser, or permission dialogs.

## Direction contract

THESIS: One continuous terminal scrollback, not a chat app assembled from cards,
bubbles, avatars, and a toolbar. The fixed prompt and restrained status line are
the only persistent controls.

OWN-WORLD: Delta Support's flat neutral terminal system: embedded Iosevka
Regular at 13 logical pixels, 1.2 line height, light `#F9F8F6`/`#2E2E2E` and
dark `#171717`/`#D1D1D1` themes, square surfaces, bracketed controls, and semantic
lime/red/orange/blue only for state.

STORY: The operator opens the panel, submits a task, watches assistant output
and compact tool receipts in chronological order, can abort, then hides the panel
without losing the conversation.

FIRST VIEWPORT: A centered 760×520 square panel. One fixed status line shows
product, model, and backend state; the scrollback fills the remaining height; a
single `>` prompt stays fixed at the bottom. No sidebar, cards, avatars, or
decorative frame.

FORM: Single scrollback, the fourth grounded structure and the dealt lead.
Seed key: `e98e5184`.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
