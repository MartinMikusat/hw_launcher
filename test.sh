#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ODIN_LIBS=$(CDPATH= cd -- "$ROOT/../odin_libraries" && pwd)

# shellcheck disable=SC2086
hw-odin test "$ROOT" \
  -collection:delta_support="$ODIN_LIBS/hw_odin_delta_support" \
  -collection:components="$ODIN_LIBS/hw_odin_ui_components" \
  -collection:hw_clay="$ODIN_LIBS/hw_clay" \
  -collection:ui_framework="$ODIN_LIBS/hw_odin_ui_framework" \
  -extra-linker-flags:"-framework AppKit -framework Foundation -framework Metal -framework QuartzCore -framework CoreText -framework CoreGraphics -framework Carbon"
