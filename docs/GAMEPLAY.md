# Gameplay guide

[Back to the README](../README.md)

Kyma is a one-on-one duel seen from above, in a minimal white world where the fighters are faceted single-color figures. The camera turns with you: where you aim is always the top of the screen.

## Controls

Every key below can be changed in Settings > Key bindings (two keys per action, Backspace clears one, Restore defaults resets them all). Keys are stored by their position on the keyboard, so the defaults work on QWERTY and AZERTY alike, and every hint in the game shows your own keys.

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
| Chat | `Enter` to type and send, `Tab` to switch to your team in Teams, `Escape` to cancel |
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
| Sniper | 100 (one shot) | 4 / 8 | The only laser others can see, even when they can't see you |
| Silencer | 30 | 10 / 30 | No noise; its shots are only shown to players who can see you |
| LMG | 15 | 60 / 60 | Automatic, 12 shots per second; heavy: you move at 72% speed and can't slide |

- The magazine reloads by itself when it is empty, or with `R`. You can't shoot while reloading.
- Weapons wait on the circles drawn on the floor: the rifle in the middle, two shotguns at the top and bottom, and a sniper, a silencer and an LMG on each side, placed symmetrically for both spawns. A taken weapon comes back 10 seconds later. The weapon card shows the trait of the weapon you hold.
- Ammo packs: walking over one with a weapon in hand adds one magazine of that weapon to your reserve (up to twice its starting reserve; a `+` shows next to the reserve). An eliminated player drops one next to their weapon, and two ammo pads sit between the spawns and the middle. A full reserve leaves the pack on the floor.
- Throwing your weapon (`G`) sends it flying: it deals 45 damage to the opponent it hits, then lands with its remaining ammo, ready to be picked up by anyone. With empty hands you pick up a weapon just by walking on it; `E` swaps the weapon you hold for the one on the floor.
- With empty hands, left click strikes: 25 damage at arm's reach (about 46 units, in front of you), every half second. The strike stuns for 0.4 s (slow, no shooting, no dash, no pickup) and knocks the opponent's weapon to the floor, so throwing your weapon and rushing in is a real play.
- While dashing you can't shoot, but bullets and thrown weapons go through you: time it to dodge.
- Pressing dash while running forward turns it into a slide: longer (about 210 units), fast at first then slowing down, and you can shoot during it. You are only untouchable during its first 8 ticks, so a slide that ends in the open can be punished. The dash card reads `Slide` when it would slide. It shares the dash cooldown and makes noise.
- You only see what is in front of you (a cone of about 110 degrees, up to 380 units away, fading into the fog over its last part) and a small circle around you, and walls block the view. You can still shoot further than you see. Everything else is greyed out, and the opponent is invisible there.

## Modes

| Mode | Players | Win |
| --- | --- | --- |
| Duel | 2 | First to 10 eliminations |
| Free for all | up to 6 | First to 15 |
| Teams | up to 4 against 4 | First team to 25 |
| Gun game | up to 6 | Climb the 7 weapons, win with a strike |

- In Gun game every elimination gives you the next weapon: pistol, silencer, shotgun, rifle, LMG, sniper, then your fists. A strike kill on the last step wins. Ammo is endless, weapons can't be picked up, thrown or knocked out, and the map only spawns health packs.

- In Teams, your teammates (blue) are always visible, can't be hurt by you and don't show up as echoes. Enemies are red.
- Team vision is shared: an enemy seen by a living teammate shows up for the whole team as a faded figure with a pulsing red target, even outside your own view, and a red arrow on the edge of the screen points to it when it is off screen.
- Every game opens on a **warmup**: move, shoot and try weapons freely, kills don't count. Press `F` when you are ready; when every player is ready (bots always are) and there are at least two, a 5 second countdown starts the match, and anyone unreadying cancels it. After a match everyone goes back to the warmup, which is also when new players join in.
- When someone eliminates you, a **killcam** replays the last two seconds from their eyes (their view cone, their shots) while you wait to respawn; `Space` skips it.
- You respawn on the spawn farthest from your enemies (your own side in Teams).
- When someone reaches the score, the match ends for everyone: the scoreboard shows for 8 seconds and a new match starts on the same map.
- Hold `Tab` for the scoreboard. In practice, bots fill every free slot.

## Maps

| Map | Size | Character |
| --- | --- | --- |
| Atrium | 1800 x 1200 | The original hall: pillars, half walls, every weapon in reach |
| Offices | 2400 x 1600 | Eight offices on one long corridor, doors and glass walls, a sniper lane |
| Greenhouse | 2200 x 1500 | Three halls split by glass: you see everything, a shot through a pane gives you away |
| Crossroads | 2400 x 1600 | Two fortified bases, three lanes and a cross in the middle, made for teams |
| Vault | 2000 x 2000 | A sealed vault with four doors holds the sniper and the LMG |
| Colonnade | 2400 x 1400 | A wide hall of columns and benches, long sightlines |
| Labyrinth | 1600 x 1600 | Tight corridors and a few doors, shotgun territory |
| Chasm | 2600 x 1400 | A chasm you can see and shoot across, crossed by three bridges |
| Courtyard | 2200 x 2200 | A ring of rooms with windows around an open courtyard |
| Warehouse | 2400 x 1600 | Shelves, crate stacks and glass offices hiding the heavy guns |
| Rooftops | 2400 x 1400 | Three roofs split by gaps you see and shoot across, four planks to cross, two snipers |
| Metro | 2600 x 1200 | Two platforms and the tracks between them, three crossings, the sniper sits on the middle one |
| Bunker | 1600 x 1600 | Nine rooms joined by doors, close fights everywhere, the LMG in the middle room |
| Gallery | 2200 x 1400 | Glass display cases: you see everyone through them but must break the glass to shoot |

Every map has four spawns per team and works in all modes; teammates never spawn on top of each other. Except the Labyrinth, they are point symmetric, so both teams get the same ground.

## Map elements

- **Doors** slide open when someone comes close and shut a moment after they leave. Closed, they block movement, bullets and the view; opening one makes noise.
- **Glass** lets the view through but stops movement and the first bullet, which shatters it loudly. Broken panes grow back after 25 seconds.
- **Low cover** (desks, crates, railings) blocks movement but not bullets or the view.
- **Chasms** block movement but not bullets or the view.
- **Health packs** (white box, red cross) heal 50 when you walk over them hurt.

## Noise

- Everything loud leaves an echo for an opponent who can't see you: a shot (heard from far away), a dash, footsteps while running, a thrown weapon and the clank of a weapon hitting a wall.
- The echo is a ring on the floor, visible through the grey area outside your view; when it is off screen, an arrow on the edge of the screen points to it. Shots are red, the rest is dark.
- Bullets betray the shooter: each shot leaves a smoke trail along its path for about a second, visible even in the grey area, and bullet holes stay on the walls for 10 seconds. Following a trail back leads to where the shot came from.
- Holding `C` (or `Ctrl`) makes you walk at less than half speed without footsteps. Throwing an empty weapon somewhere makes a noise there: use it to lure the opponent.

## Sound

Every action has its own synthesized sound: one shot per weapon, reloads and dry fire, dashes, slides, strikes and punches, hits, eliminations, doors, breaking glass, pickups, ammo, healing, level ups, the countdown, the start and the end of a match, and the menu. Sounds from the world get quieter with distance and come from the left or the right of the screen, which turns with you, so you can hear where a fight is. The volume is in Settings.

## Feel

The camera shakes with every shot you fire, harder for the shotgun and the sniper than for the pistol and barely with the silencer. Taking a hit shakes it more the bigger the hit, dying shakes it hard, landing a punch, a hit or a kill gives a small jolt, and shots fired near you shake it a little. Settings > Screen shake sets it to Full, Low or Off.

Big moments also freeze the picture for a split second (a hitstop): your kills (0.1 s), punches that land, your death, and any hit of 40 damage or more, given or taken. Everyone on screen holds still, then eases back into place; the game itself keeps running underneath, so no input is lost.

Every shot kicks the gun back into the shooter's body, then it settles: the sniper and the shotgun kick hardest, the silencer least. Your own shots also push the camera back a little and let it spring home (scaled by Screen shake). You see the kick on enemies you can see too, which tells you when they fire.

## Screen

- Top left: the game state (waiting for an opponent or duel, the dot pulses while waiting) and the `H` reminder. Top middle: the score. Top right: your ping and the eliminations, which slide in and fade out.
- Bottom left: your health, with a light trail showing the damage you just took, and the dash bar, which shows `Space` when the dash is ready.
- Bottom right: your weapon, the ammo left in the magazine and in reserve, one mark per bullet, a ring while reloading, and the key to press when it matters (`R` when the magazine runs low, `G` when the weapon is empty).
- A red arc around you points to where the last shots came from, and the screen edges flash red when you are hit.
- Standing on a weapon shows the `E` prompt to swap it.

## Main menu

- **Play**: pick a mode and one of the fourteen maps (each tile shows its layout, the panel below its doors, glass and loot), then practice against bots (easy, medium or hard: they see, turn and react like players, with more delay and less precision at lower levels; they fill every free slot) or host the game on your network.
- **Multiplayer**: games hosted on your network show up by themselves with their mode and map, click one to join (or to watch it when it is full); or type the address of a dedicated server and Connect or Watch.
- **Spectating**: Watch next to Start practice fills the chosen mode and map with bots and lets you watch them; Watch in Multiplayer follows a real game. The camera follows one player with their view; the arrow keys, or a click, switch to the next one. Spectators can chat and don't take a player slot.
- **Profile**: your name, the color of your body (only you see it, so enemies stay red and allies blue for everyone), an accent color and a head shape (hex, round, crest or visor) that everyone sees, with a live preview.
- **How to play**: the mechanics and weapons on one page. **Settings**: mouse sensitivity, camera distance, fullscreen, VSync, the live duel behind the menu and the controls reminder, saved automatically.
- Behind the menu two bots fight a live duel. Navigate with the mouse or with the arrows, `Enter` and `Escape`.
- In game, `Escape` opens the pause menu: resume, settings, leave the duel or quit. The duel keeps running while it is open.

## Playing

- The dash is a short burst (135 units in 0.15 s) in the direction you are moving, or straight ahead when standing still. It recharges in 1 second: the bar at the bottom of the screen fills up when it is ready again.
- From the command line: `love . --practice hard` starts a practice game, `love . --host` hosts a duel, `love . --connect <ip>:6789` joins one, `love . --play` waits alone for an opponent on this computer.
