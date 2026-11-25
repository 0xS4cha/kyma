# Kyma

Top-down one-on-one duel shooter made with [LÖVE](https://love2d.org) 11.5, in a minimal white
world where the fighters are faceted single-color figures.

## Run

```sh
make run              # main menu: practice against a bot, host or join a duel
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
| `src/server/` | Authoritative server: transport, host, duel and practice rooms |
| `src/ui/` | UI kit shared by the menu and the HUD: cards, buttons, fields, toggles, easing |
| `src/modules/` | Game modules, auto-loaded and registered with `GM.Modules:Register(name, priority)` |
| `src/config/` | Window and game settings |
| `tests/` | Headless test suites run by `tests/runner.lua` |

- [Gameplay guide](docs/GAMEPLAY.md)
- [Technical guide](docs/TECHNICAL.md)
- [Hosting](docs/HOSTING.md)

## Credits

- [Inter](https://rsms.me/inter/) by Rasmus Andersson, under the SIL Open Font License (`assets/fonts/OFL.txt`).
