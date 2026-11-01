# skink-game — 2D game toolkit for Skink

A small game framework with two rendering backends:

- **Engine core** (`gm_core`) — `Vec2`/`Rect` math, `Entity` bodies with velocity integration, AABB collision, and a fixed-timestep `Loop`.
- **Terminal backend** (`gm_term`) — pure-Skink ASCII games: raw-mode input (termios, arrow-key decode) + an ANSI cell-buffer renderer. No dependencies beyond libc. Linux/Unix only.
- **SDL2 backend** (`sdl/` subpackage) — a real window + GPU renderer via a tiny C shim. Requires system SDL2; linked through the `[link]` manifest section so terminal-only users never need it.

## Install

```
scales add markoxley/skink-game
```

Terminal + headless games import the root:

```skink
import "mod/markoxley/skink-game/gm"          // or local path
```

For the windowed backend:

```
scales add markoxley/skink-game/sdl    # needs libsdl2-dev installed
```

```skink
import "mod/markoxley/skink-game/sdl/gmsdl"
```

## Quick start (terminal)

```skink
import "mod/markoxley/skink-game"                  // module gm
import "mod/markoxley/skink-game/gm_core"
import "mod/markoxley/skink-game/gm_term"

var ball gm_core.Entity

fn main() -> int {
    ball = gm.NewEntity(10.0, 5.0, 2.0, 1.0, "ball")
    ball.Vel = gm_core.Vec2{X: 12.0, Y: 6.0}
    gm.RunTerminal(40, 14, 30,
        fn(dt: float, key: int) -> bool {
            gm_core.Integrate(&ball, dt)
            return key != gm_term.KEY_ESC   // update(dt, lastKey); false quits
        },
        fn(scr: *gm_term.Screen) {
            gm_term.Clear(scr)
            gm_term.DrawEntity(scr, &ball, 79)  // 'O'
        })
    return 0
}
```

Runnable version: `demo_bounce.skink` — a bouncing ball you can nudge with the arrow keys:

```
skink -o bounce demo_bounce.skink && ./bounce    # needs a TTY
```

## Quick start (SDL2)

```skink
import "mod/markoxley/skink-game/sdl/gmsdl"

fn main() -> int {
    gmsdl.Run("My Game", 640, 480, 60,
        fn(dt: float, key: int) -> bool {
            return key != gmsdl.KeyEsc()
        },
        fn() {
            gmsdl.Clear(gmsdl.Color{R: 20, G: 20, B: 40})
            gmsdl.FillRect(100, 100, 64, 64, gmsdl.Color{R: 255, G: 128, B: 0})
            gmsdl.Present()
        })
    return 0
}
```

See `sdl/README.md` for the full SDL2 API, prerequisites (`libsdl2-dev`), and `SKINK_CLANG_FLAGS` overrides.

## API overview

| Layer     | Symbols                                                                                                                                                      |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `gm_core` | `Vec2`/`Rect`/`Entity`, `Add`/`Sub`/`Scale`/`Len`/`Norm`, `Overlaps`/`Contains`, `NewEntity`/`Bounds`/`Integrate`/`Collides`, `Loop(fps,update,render)`      |
| `gm_term` | `Screen` + `NewScreen`/`Clear`/`Set`/`Text`/`FillRect`/`DrawEntity`/`Present`, `EnterRaw`/`ExitRaw`, `PollKey` (`KEY_*` codes), `Run(w,h,fps,update,render)` |
| `gm`      | re-exports: `NewEntity`, `Loop`, `RunTerminal`                                                                                                               |
| `gmsdl`   | `Open`/`Close`, `Clear`/`FillRect`/`DrawEntity`/`Present`, `PollKey`, `Run(title,w,h,fps,update,render)`, `Key*` scancode helpers                            |

## Tests

```
bash run_tests.sh
```

Covers math, integration, collision, the real-time loop, and the terminal cell buffer — plus a headless SDL2 link test when SDL2 is installed (`SDL_VIDEODRIVER=dummy`; skipped otherwise).
