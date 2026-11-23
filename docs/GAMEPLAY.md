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
| Fire | Left click (hold for the rifle) |
| Reload | `R` |
| Throw your weapon | `G` or middle click |
| Pick up / swap weapon | `E` |
| Zoom | Mouse wheel |
| Release the mouse | `Escape` (click to capture it again, `Escape` again to quit) |

## Combat

- You have 100 health and start with a pistol. Getting eliminated drops your weapon on the floor; you come back 2 seconds later at your spawn with a new pistol. Every elimination scores a point.
- Weapons:

| Weapon | Damage | Magazine / reserve | Notes |
| --- | --- | --- | --- |
| Pistol | 34 (3 hits) | 8 / 32 | One shot per click |
| Rifle | 22 | 24 / 48 | Automatic, 10 shots per second |
| Shotgun | 7 pellets of 14 | 5 / 15 | Wide spread, short range |

- The magazine reloads by itself when it is empty, or with `R`. You can't shoot while reloading.
- The rifle waits in the middle of the arena and two shotguns at the top and bottom, on the circles drawn on the floor. A taken weapon comes back 10 seconds later.
- Throwing your weapon (`G`) sends it flying: it deals 45 damage to the opponent it hits, then lands with its remaining ammo, ready to be picked up by anyone. With empty hands you pick up a weapon just by walking on it; `E` swaps the weapon you hold for the one on the floor.
- While dashing you can't shoot, but bullets and thrown weapons go through you: time it to dodge.
- You only see what is in front of you (a cone of about 110 degrees) and a small circle around you, and walls block the view. Everything else is greyed out, and the opponent is invisible there.

## Playing

- The dash is a short burst (135 units in 0.15 s) in the direction you are moving, or straight ahead when standing still. It recharges in 1 second: the bar at the bottom of the screen fills up when it is ready again.
- Solo: `love .` drops you alone in an arena while waiting for an opponent.
- Duel on a network: one player runs `love . --host`, the other `love . --connect <ip>:6789`.
