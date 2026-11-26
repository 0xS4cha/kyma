# Extraction mode

[Back to the README](../README.md)

The Wilds is an extraction shooter played on the official server only: one persistent world, 40 000 x 40 000 units (about 200 times the Embassy map), shared by up to 64 players at once. You go in with the gear you choose, loot buildings, fight monsters and other players, and leave through an extraction point. What you carry out goes to your stash. If you die, everything you carried stays on your body for others to take.

Open it from **Extraction** in the main menu.

## The loop

1. **Hub.** Equip your gear, learn plans, craft and recycle at the workbench. There is no money and no trader: what you have is what you found, crafted or recycled. If you lose everything, the **Free kit** button gives a P9, ammo, bandages, a sling bag and a frag grenade every 10 minutes.
2. **Deploy.** You spawn on a road crossing near the edge of the map, away from other players and monster nests. Monsters ignore you for your first 10 seconds.
3. **Loot.** Every building holds containers (crates, lockers, cabinets, medical boxes, weapon cases...). The closer to the centre, the more dangerous the area and the better the loot.
4. **Extract.** Stand in an extraction zone (the green circles on the map and the compass at the top of the screen) for 8 seconds. Your gear goes back to your profile.

Leaving the game does not save you: your character stays in the world for 30 seconds, vulnerable. If it survives, you keep your gear. If you come back within those 30 seconds, you take your character back where it stands.

## Controls

Every key below is a regular key binding (Settings > Key bindings), and every hint in the mode shows your own keys.

| Action | Default keys |
| --- | --- |
| Move, turn, dash, walk quietly, reload | As in the duel modes |
| Fire | Left click |
| Primary / secondary weapon | `1` / `2` |
| Quick slots (utilities) | `3` `4` `5` `6` |
| Pick up an item, open a container or a body (again to close it) | `E` |
| Inventory | `Tab` |
| Map (wheel to zoom) | `M` |
| Pause (the world keeps running) | `Escape` |

The compass tape at the top turns with you: it shows your heading, the cardinal points (N in red), the three closest extractions as green diamonds and the events in their colour, with the name and distance of the nearest extraction under it. Arrows on the screen edges show the same extractions and events. The minimap is the duel modes' one: a card in the corner set in Settings > Mini-map, with its size, opacity and zoom, north up or turned with you (then a red N marks north). It always follows you, since the world is too big to show whole. As in the duel modes, a status pill in the top left corner says where you are and how dangerous it is, with the inventory and map keys under it, and your ping sits in the top right corner. A red arc around you shows where a hit came from.

The HUD uses the cards of the duel modes: health with the wear of your vest and helmet under it, the weapon in hand with its rarity, its ammo and the magazine as pips, and a card above it for the quick slots and your other weapon. When you arrive, a banner names the area and its danger. Extracting fills a ring with the seconds left, and the end of a raid shows its time, the items you brought back and your kills.

Opening the inventory takes your hands: you can't move, turn, fire or dash while it is open, so find a safe spot first.

In the inventory:

- **Drag** an item to move it. **R** (or your reload key) rotates it while you drag. Dropping a stack on the same item merges them.
- **Drop an attachment on a weapon** to fit it. Detach it from the right click menu.
- **Drop a utility on a quick slot** to bind it. Right click the quick slot to clear it.
- **Shift click** moves an item between your gear and the open container (or the stash in the hub).
- In the hub, **drag an item on the recycle zone** of the workbench (or right click it) to take it apart into materials.
- **Drag an item outside the panels** to drop it on the ground.

## The world

The land is shaped by noise rather than a grid. Elevation makes lakes in the hollows (water you can shoot over but not cross) and rocky highlands on the heights; moisture splits forests from open fields. About 130 settlements are scattered over it and joined by winding roads, with bridges where they cross water. Danger goes up from the edges (tier 1) to the centre (tier 4).

| Area | What is there |
| --- | --- |
| Forest | Dense trees, cabins now and then, hidden stashes |
| Fields | Open ground, fences, hay bales, barns |
| Highlands | Rocks and boulders, hidden stashes |
| Lake | Water and sandy shores |
| Villages and towns | Houses with rooms, doors and windows, parked cars, park trees |
| Industrial | Warehouses with shelves, rows of shipping containers |
| Military | Fenced camps with bunkers, weapon cases and ammo crates (tiers 3 and 4) |
| Citadel | The fortress in the very centre, where the Warden may appear |

You can tell the danger by sight: the deeper you go, the darker and redder the ground (and the map), a red dashed line with chevrons marks where it goes up, and a banner tells you when you cross into an easier or a harder area. Street lamps stand along the roads, alternating sides. Their warm light is drawn over the fog, so a lit street shows from afar even where you can't see, though the fog still hides who stands in it; each lamp breathes a little and now and then one flickers. They are only drawn, worked out from the roads, so they block nothing.

Players arrive at the gates on the map edges or on roads near them; extraction points sit at gates and on a few roads further in. The world is generated from a seed: the server sends only the seed, and every client rebuilds the same map.

## Items and rarities

Every item takes a number of cells in the grid. Weapons, attachments, armor, backpacks, utilities and plans have a rarity, shown by the colour of their cell:

| Rarity | Effect |
| --- | --- |
| Common (grey) | Base stats, 1 attachment |
| Uncommon (green) | +6% power, 2 attachments |
| Rare (blue) | +12% power, 3 attachments |
| Epic (purple) | +20% power, 4 attachments |
| Legendary (orange) | +30% power, all 6 attachments |
| Mythic (red) | +42% power, all 6 attachments; mostly from events and the Warden |

On a weapon, rarity raises damage, magazine and range and tightens the spread. On an attachment it raises the strength of its effect (a mythic bouncing round bounces three times). On armor it raises protection and durability. On a plan it is the highest rarity you can craft.

- **36 weapons**: pistols (P9, derringer, machine pistol, silenced pistol, revolver, hand cannon, flare gun, nail gun), SMGs, assault rifles, carbines, semi and lever action rifles, battle and heavy rifles, pump, auto, double, sawed-off, slug and drum shotguns, bolt and marksman snipers, an anti-materiel rifle, a crossbow, a railgun, LMGs, a rotary gun, a flamethrower and a grenade launcher. Each one has a caliber among 10 kinds of ammunition.
- **48 attachments** in 6 slots (muzzle, barrel, magazine, optic, underbarrel, rounds). Examples: suppressor, flash hider, choke, match barrel, drum and belt magazines, scope, thermal sight, flashlight, strobe light, bipod, and rounds that **bounce**, **pierce**, **explode**, set targets **on fire**, **poison**, **freeze**, **arc** to another enemy, **heal you**, **mark** the target through walls, **knock back**, **split** in two, ignore armor or finish off wounded targets.
- **21 utilities** for the quick slots: bandage, food, medkit, trauma kit, stim, adrenaline, painkillers, antidote, energy drink, armor plate, frag, sticky bomb, smoke, flashbang, molotov, cryo and gas grenades, noisemaker, tripmine, pulse scanner, and an extraction flare that calls your own extraction where you stand.
- **10 helmets and vests** (gas mask, night vision, fire suit, juggernaut...) and **5 backpacks**, from the 2x3 sling bag to the 6x6 hauler frame. Space is tight on purpose: 3 pocket cells, a 10x24 stash, ammo stacks of 40 at most and material stacks of 12.
- **20 crafting materials** (scrap metal, screws, springs, string, cloth, duct tape, planks, glue, gunpowder, chemicals, wires, circuit boards, lenses, steel plates, polymer, fuel, batteries, rare alloy, monster fangs, glowing cores), and valuables (phones, watches, graphics cards, relics...) that are only worth what they recycle into.

## Plans and crafting

Every weapon, attachment, utility, armor and backpack has a **plan**. Plans drop in containers (more in cabinets, drawers, hidden stashes and supply drops). Right click a plan in your stash and choose **Learn** to know the recipe at the plan's rarity. A better plan of the same item replaces a weaker one.

At the **workbench** (hub, Workbench tab), choose a known recipe and a rarity up to your plan. Materials come from your stash. Higher rarities cost more materials, plus rare alloy from epic and glowing cores from legendary. Ammunition, bandages, food, the P9, the sawed-off, the cap, the sling bag, the red dot, the oil can suppressor, frags and smokes are known from the start.

## Recycling

At the workbench, any item but materials and plans can be taken apart: you get back about half of its recipe **at its rarity** (an epic rifle gives rare alloy, a legendary one glowing cores too), plus what its attachments are made of. Ammunition turns back into gunpowder, and valuables have their own parts: a graphics card gives circuit boards, a gold chain rare alloy, a relic alloy and a glowing core. Recycling is refused when the stash has no room for the materials, so nothing is ever lost.

## Monsters

Nests across the map wake up when a player comes within 2 600 units and go back to sleep when the area has been empty for 45 seconds. A cleared nest comes back after 2 minutes.

| Monster | How it fights |
| --- | --- |
| Crawler | Fast, weak, comes in numbers |
| Stalker | Dark and quick, hits hard, hears well |
| Brute | Slow tank that knocks you back |
| Spitter | Keeps its distance and spits poison |
| Sentinel | Armored machine that fires bursts (industrial and military areas) |
| The Warden | Event boss: armored, fires long bursts, summons crawlers, drops mythic loot |

Monsters are drawn like the players, with the same faceted body, head and feet, each in its own colour and size, with coloured eyes; sentinels carry a rifle and the Warden a machine gun. Monsters see all around them, hear gunshots, footsteps and explosions, and find their way around walls. Doors open for them too.

## Random events

Every few minutes an event starts somewhere on the map. Everyone gets a banner and a marker on the map:

- **Supply drop**: a crate full of rare loot lands after 30 seconds, guarded by sentinels.
- **Horde**: crawlers, stalkers and brutes gather; killing them all leaves a cache.
- **The Warden**: the boss walks the wilds (often in the citadel).
- **Rift**: every container around it is restocked with better loot, and stalkers come out.
- **Helicopter**: a temporary extraction point open for two minutes.

## Playing it locally

```sh
make dev                 # a local official server on port 6795, and a game window in the mode
make dev DEV_CLIENTS=2   # two windows, two different players (each has its own --profile)
make dev-server          # only the server; join from the menu with OFFICIAL_SERVER=127.0.0.1:6795 in .env
make dev-reset           # wipe the local profiles (.dev/extraction.json)
```

Command line flags for testing: `--extraction` joins the mode (with `--connect host:port`), `--profile name` uses a separate identity, `--deploy` deploys as soon as the hub opens, `--show inventory|map` opens a panel on deploy.

## Art

The world, the characters and the monsters use the game's own drawing style, and the land uses the arenas' palette: cool greys from the theme (light or dark), white tops and blue-grey shadows. Areas are only a little lighter or darker, water is a pale blue-grey, roads are grey with white dashes, and trees, rocks, cars and shipping containers are greys with now and then a red one. Most item icons come from Kenney's [Generic Items](https://kenney.nl/assets/generic-items) pack, CC0 (`assets/kenney/items`, license alongside); weapons use the gun models of the rest of the game (each of the 36 weapons borrows the model, sound and recoil of the closest of the 11 game guns), and attachments, armor and the rest are drawn in the same flat style by `src/modules/extraction/icons.lua`.

## How it works

- **Official only.** The mode runs only on a dedicated server started with `--official` or `OFFICIAL=1` (set in `docker-compose.yml`). Other servers refuse it.
- **Everything is server side.** Profiles live in `extraction.json` in the data directory (`--data` / `DATA_DIR`), keyed by the hashed player identity, like the ratings: stash, gear, learned plans and stats, plus a counter so item ids never repeat. While you are in the world, your character's gear *is* your profile gear, saved every 10 seconds, so a crash never duplicates or deletes loot. Clients only send requests (`xhub` in the hub, `xact` in the world); the server checks every one of them: distance to containers, item ownership, grid space, attachment slots, recipes and plan rarity.
- **Simulation** (`src/game/extraction/`): `worldgen.lua` builds the map (noise fields, settlements, roads, water); `terrain.lua` buckets its 15 000 walls, 2 500 doors and 2 400 windows in 256-unit cells so collisions, bullets and vision only look nearby; `world.lua` runs players, containers, inventories and extraction; `fight.lua` resolves shots with lag compensation and every round trait, armor, deaths, grenades, mines, fire and gas; `monsters.lua` runs nests and monster AI with a local A* (`pathing.lua`) that tests cells on demand; `events.lua` runs the random events; `loot.lua` rolls container contents by tier; `items.lua` and `inventory.lua` (shared with the client) compute effective weapon stats and handle the grids.
- **Server** (`src/server/extraction/`): `realm.lua` runs the world at 60 ticks per second, the hub actions, deployments, the 30 second grace after a disconnect, deaths and extractions; `store.lua` keeps the profiles.
- **Networking.** Snapshots (`xs`, 30 Hz, unreliable) carry only what a player can see or hear within 1 400 units: visible players and monsters (vision cone, flashlight and scope range, thermal radius, marks), ground items, bodies, emptied containers, open doors and broken windows nearby, shots, noises, smokes, fires, gas, projectiles and explosions, plus the events and extraction points. The inventory view (`xinv`) is sent when it changes.
- **Client** (`src/modules/extraction/`): the same prediction and reconciliation as the duel modes (`Player.step` with the weapon stats from the inventory), interpolated players and monsters, and rendering that only visits the terrain around the camera.
- **Performance**: with 64 players and 420 monsters awake, a server tick takes about 2 ms (`tests/extraction_sim_test.lua`).
