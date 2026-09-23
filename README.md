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
