# Gameplay guide

[Back to the README](../README.md)

Kyma is a one-on-one duel seen from above, in a minimal white world where the fighters are faceted single-color figures. The camera turns with you: where you aim is always the top of the screen.

## Controls

| Action | Keys |
| --- | --- |
| Move forward / back | `W` / `S` (`Z` / `S` on AZERTY), or arrow up / down |
| Strafe | `A` / `D` (`Q` / `D` on AZERTY) |
| Turn | Mouse, or arrow left / right |
| Dash | `Space`, `Shift` or right click |
| Zoom | Mouse wheel |
| Release the mouse | `Escape` (click to capture it again, `Escape` again to quit) |

## Playing

- The dash is a short burst (135 units in 0.15 s) in the direction you are moving, or straight ahead when standing still. It recharges in 1 second: the bar at the bottom of the screen fills up when it is ready again.
- Solo: `love .` drops you alone in an arena while waiting for an opponent.
- Duel on a network: one player runs `love . --host`, the other `love . --connect <ip>:6789`.
