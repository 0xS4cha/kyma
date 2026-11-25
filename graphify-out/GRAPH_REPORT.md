# Graph Report - kyma  (2026-11-25)

## Corpus Check
- 162 files · ~104,194 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 8 file(s) not represented in the graph (top: (none) 5, .ttf 2, .example 1)

## Summary
- 1203 nodes · 2696 edges · 59 communities (52 shown, 7 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 491 edges (avg confidence: 0.85)
- Token cost: 97,356 input · 0 output

## Community Hubs (Navigation)
- Camera and Game Feel
- Visual Effects
- Text, UUID and Identity
- LÖVE Entry Point
- JSON Library
- HUD Rendering
- Menu System
- Profile and Tournament Bracket
- Hashing and RNG
- Multiplayer Client Module
- Player and Session
- Game Setup and Bot Tests
- Audio Synthesis
- Menu Common and How-To
- Tournament Lobby View
- Combat System
- Netcode and Engine Docs
- Build Package Workflow
- Server Rooms
- Weapons
- World Simulation
- Root Menu and Settings
- Screen Draw Helpers
- Player-Facing Features Docs
- Binary Buffer IO
- CI Workflow
- Arena Map Mechanics
- Bots and Navigation
- Gadgets
- Tournament Screen
- Keybinds
- Docker Compose Config
- Game Modes and Loadouts Docs
- Infiltration Rounds
- Hosting and Matchmaking Docs
- Maps and Play Screen
- Network Client
- Vision and Combat Tests
- Pause Menu and Minimap
- Packet Codec
- Network Server
- Protocol and Chat Tests
- Project Overview and Font
- Loadout Config
- Movement and Killcam Docs
- Keybinds Screen
- Loadout Screen
- Online Browser Screen
- Fog of War and Noise Docs
- Maps Docs
- Window Config
- Deterministic Math
- Ordered Iteration
- App Icon
- Install Script

## God Nodes (most connected - your core abstractions)
1. `Technical guide` - 44 edges
2. `Kit.text()` - 33 edges
3. `Gameplay guide` - 29 edges
4. `Kit.color()` - 26 edges
5. `Arena.new()` - 25 edges
6. `Hud:draw()` - 23 edges
7. `Kit.card()` - 22 edges
8. `World.new()` - 21 edges
9. `Weapons.def()` - 20 edges
10. `Kit.clamp()` - 20 edges

## Surprising Connections (you probably didn't know these)
- `open()` --calls--> `Arena.new()`  [INFERRED]
  tests/dash_test.lua → src/game/arena.lua
- `open()` --calls--> `Arena.new()`  [INFERRED]
  tests/gadgets_test.lua → src/game/arena.lua
- `arena()` --calls--> `Arena.new()`  [INFERRED]
  tests/map_systems_test.lua → src/game/arena.lua
- `arena()` --calls--> `Arena.new()`  [INFERRED]
  tests/slide_test.lua → src/game/arena.lua
- `step()` --calls--> `Player.packAngle()`  [INFERRED]
  tests/weapons_test.lua → src/game/player.lua

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Client-server netcode pipeline** — docs_technical_input_commands, docs_technical_authoritative_server, docs_technical_snapshots, docs_technical_prediction_reconciliation, docs_technical_interpolation, docs_technical_lag_compensation [EXTRACTED 1.00]
- **Fog-of-war information mechanics** — docs_technical_vision_filtering, docs_technical_noise, docs_technical_shared_vision, docs_technical_weapon_traits, docs_technical_gadgets [INFERRED 0.85]
- **Dedicated server deployment options** — docs_hosting_docker, docs_hosting_pterodactyl_egg, docs_hosting_systemd, docs_hosting_server_flags [EXTRACTED 1.00]

## Communities (59 total, 7 thin omitted)

### Community 0 - "Camera and Game Feel"
Cohesion: 0.05
Nodes (61): Camera:anchor(), Camera:apply(), Camera:rotation(), Camera:toScreen(), Camera:toWorld(), Camera:update(), Bot.new(), Vision.fans() (+53 more)

### Community 1 - "Visual Effects"
Cohesion: 0.05
Nodes (54): Character.fire(), Effects:drawScreen(), Effects:impact(), Effects.new(), Effects:spray(), Effects:tracer(), Hitstop.new(), Hitstop:pose() (+46 more)

### Community 2 - "Text, UUID and Identity"
Cohesion: 0.05
Nodes (35): sequence(), Text.chars(), Text.clean(), Text.dropLast(), Text.length(), bs2num(), getUUID(), num2bs() (+27 more)

### Community 3 - "LÖVE Entry Point"
Cohesion: 0.05
Nodes (18): love.draw(), love.load(), love.update(), screenshot(), ArgParser.new(), Logger:error(), Logger:info(), Logger:test_fail() (+10 more)

### Community 4 - "JSON Library"
Cohesion: 0.07
Nodes (30): codepoint_to_utf8(), decode_error(), json.decode(), json.encode(), next_char(), parse_array(), parse_literal(), parse_number() (+22 more)

### Community 5 - "HUD Rendering"
Cohesion: 0.09
Nodes (39): pop(), clock(), edge(), Hud:draw(), Hud:drawBanner(), Hud:drawBlind(), Hud:drawBoard(), Hud:drawChat() (+31 more)

### Community 6 - "Menu System"
Cohesion: 0.09
Nodes (38): find(), GM.Menu:active(), GM.Menu:back(), GM.Menu:Draw(), GM.Menu:drawScreen(), GM.Menu:drawVeil(), GM.Menu:elements(), GM.Menu:Initialize() (+30 more)

### Community 7 - "Profile and Tournament Bracket"
Cohesion: 0.10
Nodes (31): PROFILE.sanitize(), Bracket:decide(), Bracket:Forfeit(), Bracket:needed(), Bracket.new(), Bracket:Playable(), Bracket:ready(), Bracket:Report() (+23 more)

### Community 8 - "Hashing and RNG"
Cohesion: 0.07
Nodes (17): fmix(), Hash.combine(), Hash.toggle(), mul32(), u32(), Random.new(), Random:next(), Random:random() (+9 more)

### Community 9 - "Multiplayer Client Module"
Cohesion: 0.09
Nodes (25): Play.enter(), GM.Multiplayer:announce(), GM.Multiplayer:Connect(), GM.Multiplayer:Disconnect(), GM.Multiplayer:dispatch(), GM.Multiplayer:FindMatch(), GM.Multiplayer:Flush(), GM.Multiplayer:Initialize() (+17 more)

### Community 10 - "Player and Session"
Cohesion: 0.09
Nodes (22): Combat.killcam(), Player.copy(), Player.new(), Player.packAngle(), Player.respawn(), Player.running(), Player.step(), Player.unpackAngle() (+14 more)

### Community 11 - "Game Setup and Bot Tests"
Cohesion: 0.08
Nodes (13): Arena.new(), copy(), Combat.setup(), Gadgets.setup(), World.new(), open(), game(), duel() (+5 more)

### Community 12 - "Audio Synthesis"
Cohesion: 0.08
Nodes (13): freeVoice(), GM.Audio:count(), GM.Audio:Initialize(), GM.Audio:Master(), GM.Audio:Play(), GM.Audio:PlayAt(), noiseSource(), renderLayer() (+5 more)

### Community 13 - "Menu Common and How-To"
Cohesion: 0.12
Nodes (18): Common.backElement(), Common.margin(), Common.textHandler(), Howto.build(), Howto.draw(), keys(), layout(), join() (+10 more)

### Community 14 - "Tournament Lobby View"
Cohesion: 0.15
Nodes (20): Bracket.roundName(), drawList(), drawLobby(), hit(), stateLabel(), status(), summary(), View.draw() (+12 more)

### Community 15 - "Combat System"
Cohesion: 0.21
Nodes (24): category(), Combat.damage(), Combat.drop(), Combat.fire(), Combat.heal(), Combat.kill(), Combat.melee(), Combat.noise() (+16 more)

### Community 16 - "Netcode and Engine Docs"
Cohesion: 0.14
Nodes (22): Screen shake, hitstop and recoil (feel), Audio synthesizer (src/modules/audio), Turning camera (src/core/camera.lua), Chat (rate limited), Command line flags, Dedicated server (headless, AppImage, Docker), enet channels (reliable / unreliable sequenced), Hitstop (presentation only) (+14 more)

### Community 17 - "Build Package Workflow"
Cohesion: 0.09
Nodes (21): jobs, package, name, on, push, workflow_dispatch, runs-on, steps (+13 more)

### Community 18 - "Server Rooms"
Cohesion: 0.18
Nodes (19): Room:Add(), Room:Broadcast(), Room:Chat(), Room:Count(), Room:flushEvents(), Room:freeSlot(), Room:Full(), Room:Hold() (+11 more)

### Community 19 - "Weapons"
Cohesion: 0.18
Nodes (13): noise(), Weapons.def(), Weapons.give(), Weapons.muzzle(), Weapons.pack(), Weapons.rays(), Weapons.reserveCap(), Weapons.stat() (+5 more)

### Community 20 - "World Simulation"
Cohesion: 0.17
Nodes (14): Rounds.setup(), World:add(), World:enemies(), World:hears(), World:kitOf(), World:loadout(), World:lobby(), World:remove() (+6 more)

### Community 21 - "Root Menu and Settings"
Cohesion: 0.18
Nodes (16): GM.Menu:drawWipe(), GM.Menu:stagger(), drawLive(), drawTitle(), Root.build(), Root.draw(), titleY(), layout() (+8 more)

### Community 22 - "Screen Draw Helpers"
Cohesion: 0.41
Nodes (20): Common.header(), Common.paragraph(), Screen.draw(), Screen.draw(), Multiplayer.draw(), Online.draw(), drawTile(), Play.draw() (+12 more)

### Community 23 - "Player-Facing Features Docs"
Cohesion: 0.15
Nodes (17): Ammo packs, Practice bots, Dark mode, Gameplay guide, HUD screen layout, Key bindings (scancode based), Main menu (Play, Multiplayer, Profile, Settings), Unarmed strike (+9 more)

### Community 24 - "Binary Buffer IO"
Cohesion: 0.22
Nodes (14): Reader:bytes(), Reader:check(), Reader:double(), Reader:string(), Reader:svarint(), Reader:u8(), Reader:varint(), Writer:bytes() (+6 more)

### Community 25 - "CI Workflow"
Cohesion: 0.12
Nodes (16): runs-on, steps, timeout-minutes, jobs, build, name, on, pull_request (+8 more)

### Community 26 - "Arena Map Mechanics"
Cohesion: 0.17
Nodes (11): Arena.circle(), Arena:each(), Arena:raycast(), Arena:resolve(), Arena:updateDoors(), Arena:updateGlass(), overlaps(), slab() (+3 more)

### Community 27 - "Bots and Navigation"
Cohesion: 0.24
Nodes (14): Bot:command(), Bot:nearestWeapon(), Bot:pickWaypoint(), Bot:steer(), Bot:target(), distance(), wrap(), blocked() (+6 more)

### Community 28 - "Gadgets"
Cohesion: 0.19
Nodes (11): angleBetween(), clear(), decoyShot(), detonate(), Gadgets.flash(), Gadgets.give(), Gadgets.update(), duel() (+3 more)

### Community 29 - "Tournament Screen"
Cohesion: 0.27
Nodes (14): address(), bestOfNames(), browse(), create(), cycleMap(), layout(), mapId(), modeNames() (+6 more)

### Community 30 - "Keybinds"
Cohesion: 0.26
Nodes (13): defaults(), ensure(), Keybinds.down(), Keybinds.is(), Keybinds.keys(), Keybinds.label(), Keybinds.load(), Keybinds.name() (+5 more)

### Community 31 - "Docker Compose Config"
Cohesion: 0.14
Nodes (13): MAX_PEERS, SERVER_MOTD, SERVER_NAME, build, environment, image, ports, restart (+5 more)

### Community 32 - "Game Modes and Loadouts Docs"
Cohesion: 0.18
Nodes (14): Gadgets (smoke, flashbang, decoy), Gun game, Infiltration mode (rounds on Embassy), Loadout and weapon mods, Match rules, Game modes (Duel, FFA, Teams, Gun game), Team shared vision, Weapons (pistol, rifle, shotgun, sniper, silencer, LMG) (+6 more)

### Community 33 - "Infiltration Rounds"
Cohesion: 0.25
Nodes (12): event(), index(), Rounds.alive(), Rounds.kit(), Rounds.next(), Rounds.role(), Rounds.snapshot(), Rounds.update() (+4 more)

### Community 34 - "Hosting and Matchmaking Docs"
Cohesion: 0.27
Nodes (12): Docker compose deployment, Hosting a dedicated server, install.sh, Matchmaking settings (sizes, window, widen, fillAfter), Official server (official in src/net/config.lua, OFFICIAL_SERVER in .env), Protocol version check, Pterodactyl egg (egg-kyma.json), Rated matchmaking (+4 more)

### Community 35 - "Maps and Play Screen"
Cohesion: 0.22
Nodes (8): Maps.get(), Maps.valid(), layout(), names(), Play.build(), selectedMap(), Settings.botLevel(), each()

### Community 36 - "Network Client"
Cohesion: 0.18
Nodes (4): GM.Multiplayer:Stream(), Protocol.Encode(), Client:Send(), Client:Stream()

### Community 37 - "Vision and Combat Tests"
Cohesion: 0.21
Nodes (7): angleBetween(), clear(), Vision.sees(), command(), open(), tick(), arena()

### Community 38 - "Pause Menu and Minimap"
Cohesion: 0.27
Nodes (8): confirm(), drawInfo(), layout(), Pause.build(), Pause.draw(), subtitle(), Minimap.draw(), rects()

### Community 39 - "Packet Codec"
Cohesion: 0.22
Nodes (6): Buffer.reader(), Buffer.writer(), Codec.decode(), Codec.encode(), Codec.read(), read()

### Community 40 - "Network Server"
Cohesion: 0.38
Nodes (6): Server:Emit(), Server:onConnect(), Server:onDisconnect(), Server:onReceive(), Server:Poll(), Server:Think()

### Community 41 - "Protocol and Chat Tests"
Cohesion: 0.25
Nodes (3): Protocol.Decode(), Client:SendRaw(), pump()

### Community 42 - "Project Overview and Font"
Cohesion: 0.29
Nodes (8): The Inter Project Authors, Reserved Font Name, SIL Open Font License 1.1, Inter font (Rasmus Andersson), Kyma (top-down duel shooter), LÖVE 11.5 engine, GM.Modules:Register auto-loaded game modules, Project layout

### Community 43 - "Loadout Config"
Cohesion: 0.29
Nodes (3): LOADOUT.rules(), LOADOUT.sanitize(), world()

### Community 44 - "Movement and Killcam Docs"
Cohesion: 0.29
Nodes (7): Dash, Killcam, Slide, Killcam (Combat.killcam), Lag-compensated hit detection (rewind), Melee (Combat.melee), Slide (Player.step)

### Community 45 - "Keybinds Screen"
Cohesion: 0.43
Nodes (4): columns(), layout(), Screen.back(), Screen.build()

### Community 46 - "Loadout Screen"
Cohesion: 0.38
Nodes (5): drawWeapon(), keys(), layout(), Screen.build(), title()

### Community 47 - "Online Browser Screen"
Cohesion: 0.43
Nodes (5): find(), layout(), names(), Online.build(), Online.keyPressed()

### Community 48 - "Fog of War and Noise Docs"
Cohesion: 0.40
Nodes (5): Noise and echoes, View cone and fog, Bots (src/game/bot.lua), Noise (Combat.noise, World:hears), Weapon traits (silent, exposed, speed)

### Community 50 - "Maps Docs"
Cohesion: 0.50
Nodes (5): Map elements (doors, glass, low cover, chasms, health packs), Maps (fourteen point-symmetric maps), Arena map elements (Arena:each), Bot navigation (A* grid, src/game/nav.lua), Maps (src/maps, builder.lua)

### Community 52 - "Deterministic Math"
Cohesion: 0.83
Nodes (3): DMath.exp(), DMath.log(), DMath.pow()

### Community 55 - "App Icon"
Cohesion: 0.67
Nodes (3): Kyma App Icon (red low-poly gem), Low-poly red crystal/polyhedron motif, Rounded-square light grey app tile background

## Knowledge Gaps
- **8 isolated node(s):** `LÖVE 11.5 engine`, `Reserved Font Name`, `HUD screen layout`, `systemd service`, `Input budget` (+3 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 266 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `enet channels (reliable / unreliable sequenced)` connect `Netcode and Engine Docs` to `Hosting and Matchmaking Docs`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Are the 25 inferred relationships involving `Kit.text()` (e.g. with `GM.Menu:drawWipe()` and `Common.header()`) actually correct?**
  _`Kit.text()` has 25 INFERRED edges - model-reasoned connections that need verification._
- **What connects `LÖVE 11.5 engine`, `Reserved Font Name`, `HUD screen layout` to the rest of the system?**
  _8 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Camera and Game Feel` be split into smaller, more focused modules?**
  _Cohesion score 0.0519311911716975 - nodes in this community are weakly interconnected._
- **Why does `Technical guide` connect `Netcode and Engine Docs` to `Game Modes and Loadouts Docs`, `Project Overview and Font`, `Movement and Killcam Docs`, `Fog of War and Noise Docs`, `Maps Docs`, `Player-Facing Features Docs`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 19 inferred relationships involving `Kit.color()` (e.g. with `GM.Menu:drawWipe()` and `Common.paragraph()`) actually correct?**
  _`Kit.color()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Should `Visual Effects` be split into smaller, more focused modules?**
  _Cohesion score 0.05369369369369369 - nodes in this community are weakly interconnected._