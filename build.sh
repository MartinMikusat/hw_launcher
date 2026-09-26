#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ODIN_LIBS=$(CDPATH= cd -- "$ROOT/../odin_libraries" && pwd)
BUILD="$ROOT/build"
mkdir -p "$BUILD"
# The app embeds this precompiled shader library (shaders.odin).
sh "$ODIN_LIBS/hw_odin_ui_framework/scripts/build-metallib.sh" "$BUILD/ui.metallib"

MODE=${1:-debug}
case "$MODE" in
  debug) FLAGS="-debug -o:none" ;;
  release) FLAGS="-o:speed" ;;
  *)
    echo "usage: ./build.sh [debug|release]" >&2
    exit 2
    ;;
esac

# shellcheck disable=SC2086
hw-odin build "$ROOT" $FLAGS \
  -collection:delta_support="$ODIN_LIBS/hw_odin_delta_support" \
  -collection:components="$ODIN_LIBS/hw_odin_ui_components" \
  -collection:hw_clay="$ODIN_LIBS/hw_clay" \
  -collection:ui_framework="$ODIN_LIBS/hw_odin_ui_framework" \
  -extra-linker-flags:"-framework AppKit -framework Foundation -framework Metal -framework QuartzCore -framework CoreText -framework CoreGraphics -framework Carbon" \
  -out:"$BUILD/hw_launcher"
