# Kyma

Top-down neon shooter made with [LÖVE](https://love2d.org) 11.5: the player clears rooms of enemies
with a limited field of view, under a timer, and reaches the exit.

## Run

```sh
make run              # love .
make test             # love . --test
love . --frames 300 --screenshot shot.png   # boot, render, save a screenshot, quit
```

## Layout

| Path | Role |
| --- | --- |
| `main.lua` | LÖVE callbacks, command-line flags, dispatch to modules |
| `src/core/` | Engine helpers: class, logger, camera, deterministic random, args, threads |
| `src/modules/` | Game modules, auto-loaded and registered with `GM.Modules:Register(name, priority)` |
| `src/config/` | Window and game settings |
| `tests/` | Headless test suites run by `tests/runner.lua` |

- [Gameplay guide](docs/GAMEPLAY.md)
- [Technical guide](docs/TECHNICAL.md)
