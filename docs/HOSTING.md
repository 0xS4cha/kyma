# Hosting a dedicated server

A dedicated server runs the same rooms as the game, without a window. It also
runs rated matchmaking: players who pick **Online > Find a match** are queued
per mode, grouped with players of a close rating and put in a room of their own.
Ratings are kept on the server and survive restarts.

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
| `--data`    | `DATA_DIR`    | LÖVE save dir  | Folder that holds `ratings.json`                |

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
