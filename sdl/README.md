# skink-game/sdl — SDL2 backend

Windowed 2D backend for skink-game, driven through `shim.c` (a small
C ABI — Skink only needs `extern fn` declarations).

## Prerequisites

Debian/Ubuntu:  `sudo apt install libsdl2-dev`
Fedora:         `sudo dnf install SDL2-devel`
macOS:          `brew install sdl2`

## Install + build

```
scales add markoxley/skink-game/sdl
```

The subpackage `skink.toml` carries a `[link]` section that compiles
`shim.c` and links `-lSDL2`. If headers/libs live elsewhere, export
`SKINK_CLANG_FLAGS="-I<inc> -L<lib>"` when building.

## API

```skink
import "mod/markoxley/skink-game/sdl/gmsdl"
import "mod/markoxley/skink-game/gm_core"   // optional; only needed to name core types

// manual loop
err := gmsdl.Open("My Game", 640, 480)
for running {
    gmsdl.Clear(gmsdl.Color{R: 20, G: 20, B: 30})
    k := gmsdl.PollKey()          // scancode, 0 none, -1 quit
    if k == -1 { running = false }
    gmsdl.FillRect(10, 10, 100, 60, gmsdl.Color{R: 255, G: 0, B: 0})
    gmsdl.Present()
}
gmsdl.Close()

// or the managed loop (fixed timestep, quit on window close):
gmsdl.Run("My Game", 640, 480, 60,
    fn(dt: float, key: int) -> bool { /* move */ return key != gmsdl.KeyEsc() },
    fn() { /* draw via gmsdl.FillRect + Present */ })
```

Scancode helpers: `KeyUp/Down/Left/Right/Space/Esc/W/A/S/D()`.
