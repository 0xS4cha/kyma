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
| Walk quietly | Hold `C` or `Ctrl` |
| Fire | Left click (hold for the rifle) |
| Reload | `R` |
| Throw your weapon | `G` or middle click |
| Pick up / swap weapon | `E` |
| Zoom | Mouse wheel |
| Show or hide the controls | `H` (shown for the first seconds of a game) |
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
- Ammo packs: walking over one with a weapon in hand adds one magazine of that weapon to your reserve (up to twice its starting reserve; a `+` shows next to the reserve). An eliminated player drops one next to their weapon, and two ammo pads sit between the spawns and the middle. A full reserve leaves the pack on the floor.
- Throwing your weapon (`G`) sends it flying: it deals 45 damage to the opponent it hits, then lands with its remaining ammo, ready to be picked up by anyone. With empty hands you pick up a weapon just by walking on it; `E` swaps the weapon you hold for the one on the floor.
- While dashing you can't shoot, but bullets and thrown weapons go through you: time it to dodge.
- Pressing dash while running forward turns it into a slide: longer (about 210 units), fast at first then slowing down, and you can shoot during it. You are only untouchable during its first 8 ticks, so a slide that ends in the open can be punished. The dash card reads `Slide` when it would slide. It shares the dash cooldown and makes noise.
- You only see what is in front of you (a cone of about 110 degrees) and a small circle around you, and walls block the view. Everything else is greyed out, and the opponent is invisible there.

## Noise

- Everything loud leaves an echo for an opponent who can't see you: a shot (heard from far away), a dash, footsteps while running, a thrown weapon and the clank of a weapon hitting a wall.
- The echo is a ring on the floor, visible through the grey area outside your view; when it is off screen, an arrow on the edge of the screen points to it. Shots are red, the rest is dark.
- Bullets betray the shooter: each shot leaves a smoke trail along its path for about a second, visible even in the grey area, and bullet holes stay on the walls for 10 seconds. Following a trail back leads to where the shot came from.
- Holding `C` (or `Ctrl`) makes you walk at less than half speed without footsteps. Throwing an empty weapon somewhere makes a noise there: use it to lure the opponent.

## Screen

- Top left: the game state (waiting for an opponent or duel, the dot pulses while waiting) and the `H` reminder. Top middle: the score. Top right: your ping and the eliminations, which slide in and fade out.
- Bottom left: your health, with a light trail showing the damage you just took, and the dash bar, which shows `Space` when the dash is ready.
- Bottom right: your weapon, the ammo left in the magazine and in reserve, one mark per bullet, a ring while reloading, and the key to press when it matters (`R` when the magazine runs low, `G` when the weapon is empty).
- A red arc around you points to where the last shots came from, and the screen edges flash red when you are hit.
- Standing on a weapon shows the `E` prompt to swap it.

## Playing

- The dash is a short burst (135 units in 0.15 s) in the direction you are moving, or straight ahead when standing still. It recharges in 1 second: the bar at the bottom of the screen fills up when it is ready again.
- Solo: `love .` drops you alone in an arena while waiting for an opponent.
- Duel on a network: one player runs `love . --host`, the other `love . --connect <ip>:6789`.
