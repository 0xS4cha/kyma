# Hosting a dedicated server

A dedicated server runs the same rooms as the game, without a window. It also
runs rated matchmaking: players who pick **Online > Find a match** are queued
per mode, grouped with players of a close rating and put in a room of their own.
Ratings are kept on the server and survive restarts.

Every server also hosts tournaments, created and joined from **Tournaments** in
the main menu (see below).

## Quick start

```sh
love . --server --name "My server" --motd "Hello there"
```

| Flag        | Environment   | Default        | What it does                                    |
|-------------|---------------|----------------|-------------------------------------------------|
| `--port`    | `PORT`        | `6789`         | UDP port to listen on                           |
| `--peers`   | `MAX_PEERS`   | `64`           | Most players connected at once                  |
| `--name`    | `SERVER_NAME` | `Kyma server`  | Name shown to players while they queue          |
| `--motd`    | `SERVER_MOTD` | none           | Message of the day shown while they queue       |
| `--data`    | `DATA_DIR`    | LÖVE save dir  | Folder that holds `ratings.json` and `extraction.json` |
| `--official`| `OFFICIAL`    | off            | Runs the persistent [extraction world](EXTRACTION.md) (official server only) |

Flags win over environment variables. Open the UDP port in your firewall
(`sudo ufw allow 6789/udp`) and forward it on your router if the server sits
behind one.

## Docker

```sh
docker compose up -d --build
docker compose logs -f
```

`docker-compose.yml` publishes `6789/udp` and keeps ratings in the `kyma-data`
volume. Change `SERVER_NAME`, `SERVER_MOTD` and `MAX_PEERS` there. To back the
ratings up:

```sh
docker compose cp kyma:/data/ratings.json ./ratings-backup.json
```

## Pterodactyl

`pterodactyl/egg-kyma.json` is an egg for the Pterodactyl panel. It uses the
generic `ghcr.io/parkervcp/yolks:debian` image, so there is nothing to build or
publish.

1. In the panel, go to **Admin > Nests**, create a nest (for example *Kyma*),
   then **Import Egg** and pick `pterodactyl/egg-kyma.json`.
2. Create a server with that egg. Give it one allocation: players connect over
   **UDP** on that port, so make sure the node firewall lets UDP through.
3. Set **Server name**, **Message of the day** and **Max players** on the
   server's Startup page. 256 MB of memory and one CPU core are plenty for a few
   rooms.

The install script downloads LÖVE 11.5 as an AppImage and extracts it to
`love/`, then copies the server files of the `main` branch to `game/`.
`game/REVISION` holds the commit that was installed. Ratings live in `data/`,
which a reinstall keeps, so **Reinstall Server** is how you update to the latest
commit. The panel sends `^C` to stop the server, and the server saves ratings
before exiting.

`install.sh` next to the egg is the same script. After you change it, regenerate
the egg so the script inside it matches, or `make test` fails.

## systemd

```ini
# /etc/systemd/system/kyma.service
[Unit]
Description=Kyma dedicated server
After=network-online.target

[Service]
User=kyma
WorkingDirectory=/opt/kyma
ExecStart=/usr/bin/love /opt/kyma --server --name "Kyma official" --data /var/lib/kyma
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`/opt/kyma` holds a checkout of the repository, and `/var/lib/kyma` must be
writable by the `kyma` user.

## Making it the official server

The **Online** screen connects to the address in `official` of
`src/net/config.lua`. Set it to your server (for example
`play.example.com:6789`) before building a release, so every copy of the game
queues there. A line `OFFICIAL_SERVER=host:port` in `.env` overrides it without
a rebuild, which is handy to test a staging server.

Players can always queue on another server from the same screen, through the
**Your server** field.

## Versions

Clients and servers must share `version` from `src/net/config.lua`. A client
with another version is told so and disconnected, so update the server when you
publish a release that bumps it.

## Matchmaking settings

`matchmaking` in `src/net/config.lua`:

- `sizes`: players per matchmade game for each mode.
- `window`: rating gap allowed at once, `widen`: extra gap per second waited.
- `fillAfter`: seconds before a game starts with fewer players than `sizes`
  asks for, as long as at least two are waiting.

## Tournaments

Any player can create a tournament on a server: a name, a mode, a map, a
bracket of 4, 8 or 16 seats and matches of one game or a best of three or five.
Others join it from **Browse tournaments**, and the organiser starts it once at
least two players are in.

- The bracket is single elimination, seeded by rating, and empty seats become
  byes for the top seeds.
- Each match is played in a private room that casual players never land in.
  Players who do not ready up within `readyTimeout` seconds are readied by the
  server, so a series cannot stall.
- Leaving or disconnecting forfeits the current match, and any match the player
  already reached.
- Tournament games do not change ratings.

`tournament` in `src/net/config.lua` sets how many tournaments may be open at
once (`maxOpen`), the name length, how long players stay on the result screen
before going back to the bracket (`resultDelay`, `forfeitDelay`) and
`readyTimeout`.
