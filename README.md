# Kyma

Top-down neon shooter made with [LÖVE](https://love2d.org) 11.5: the player clears rooms of enemies
with a limited field of view, under a timer, and reaches the exit.

## Run

```sh
make run              # solo: local server in a thread + client
make host             # host a duel on your network (UDP 6789)
love . --connect 127.0.0.1:6789 --name Bob   # join it
make server           # headless dedicated server
make test             # love . --test
```

## Layout

| Path | Role |
| --- | --- |
| `main.lua` | LÖVE callbacks, command-line flags, dispatch to modules |
| `src/core/` | Engine helpers: class, logger, turning camera, random, args, threads |
| `src/game/` | Simulation shared by client and server: arena, player movement, world |
| `src/net/` | Binary codec, protocol, input validation |
| `src/server/` | Authoritative server: transport, host, duel rooms |
| `src/modules/` | Game modules, auto-loaded and registered with `GM.Modules:Register(name, priority)` |
| `src/config/` | Window and game settings |
| `tests/` | Headless test suites run by `tests/runner.lua` |

- [Gameplay guide](docs/GAMEPLAY.md)
- [Technical guide](docs/TECHNICAL.md)
