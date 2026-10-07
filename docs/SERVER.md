# The dedicated server

A dedicated server runs the game on a machine of its own, with no window and nobody's computer as the host. Players connect with the
game as remote seats (the boss's, the lieutenant's, the fixer's, the controller's desks, the pilot's 3D seat and so on); every seat nobody
holds is the AI's, and the aircraft is flown by the AI until a player takes the pilot's seat. The game goes on with nobody connected, is saved,
and is picked up from the save when the server restarts.

It is the same server a hosting player runs (`HostServer`, protocol v3), plus: saves, a password, a player limit, a log, a status probe
for health checks, and a clean shutdown. The code is `scripts/net/dedicated_server.gd` and `scripts/net/dedicated.gd`.

## Run it

You need Godot 4.7.2 (`tools/get_godot.sh` downloads the pinned build for Linux). After the first checkout, `godot --headless --import`
once to build the class cache. Then:

```bash
godot --headless --path . --script res://scripts/net/dedicated.gd -- --port 47800 --mode coop --unlocks open --password secret
```

Players join with the game: `skyrunner --connect secret@YOUR_IP:47800 --role boss` (or type `secret@YOUR_IP:47800` into the Join box in the
lobby; `--role pick` shows the seat list). To check the server without joining:

```bash
godot --headless --script res://tools/server_probe.gd -- YOUR_IP 47800                          # prints its status
godot --headless --script res://tools/server_probe.gd -- YOUR_IP 47800 --join boss --password secret   # takes a seat and waits for a snapshot
printf '{"t":"status"}\n' | nc YOUR_IP 47800                                                    # the same status, with nothing but netcat
```

## Options

Every option is a flag (`--max-players 8`) or an environment variable (`SKYRUNNER_MAX_PLAYERS=8`); a flag wins.

| Option | Default | |
|---|---|---|
| `--port` | 47800 | the TCP port |
| `--bind` | `*` | the address to listen on (`127.0.0.1` for local only) |
| `--mode` | `coop` | `coop` (the runners are the players, the law is the AI), `versus` (both sides can be players), `police` (a task-force table: no pilot, AI runners) |
| `--unlocks` | `open` | `open`: every system from the first minute, with a float of money. `story`: the Costa Brava story's chapters open them one at a time (the whole table plays one story) |
| `--seed` | 1 | the game's seed (a new game only; a save keeps its own) |
| `--map` | -1 | `-1` the city coast; positive `N` generated island N; `0` is retired |
| `--name` | `Skyrunner server` | the name in the status reply and the LAN list |
| `--password` | none | a hello without it is refused; join as `password@host:port` |
| `--max-players` | 16 | at most 64 |
| `--save` | `user://dedicated.json` | where the game is kept (an absolute path, e.g. `/var/lib/skyrunner/dedicated.json`) |
| `--autosave` | 120 | seconds between saves; 0 turns it off (it still saves when the last player leaves and on a clean stop) |
| `--autopilot` | true | the AI flies the aircraft until a player takes the pilot's seat |
| `--stop-file` | none | when this file appears the server saves, deletes it and exits (see below) |
| `--lan` | off | also announce on the local network (useless in the cloud) |
| `--seconds` | none | stop after this many server seconds (for tests) |
| `--quiet` | off | no log lines on stdout |

## Stopping it cleanly

Godot does not handle SIGTERM, so a plain `kill` (or `docker stop`, or `systemctl stop`) ends the process at once, and anything since the
last autosave is lost. The server therefore watches a **stop file**: `touch /var/lib/skyrunner/stop` makes it save and exit within a second.
The Docker entrypoint and the systemd unit below do this for you.

## Docker

```bash
docker build -t skyrunner-server -f deploy/Dockerfile .
docker run -d --name skyrunner -p 47800:47800 -v skyrunner-data:/data -e SKYRUNNER_PASSWORD=secret skyrunner-server
docker logs -f skyrunner        # the log: who joined, who left, every save
docker stop -t 30 skyrunner     # saves, then stops
```

Or `docker compose -f deploy/docker-compose.yml up -d --build` (put `SKYRUNNER_PASSWORD=...` in an `.env` file beside it). The save is in the
`/data` volume. CI builds this image and checks that a container answers, serves a seat and saves on `docker stop` on every change.

## Google Cloud (Compute Engine)

Cloud Run and App Engine cannot serve a raw TCP port, so use a Compute Engine VM. `deploy/gcp/deploy.sh` creates one:

```bash
gcloud auth login
PROJECT=my-project REPO=https://github.com/you/skyrunner.git PASSWORD=secret ./deploy/gcp/deploy.sh
```

It reserves a static IP, opens TCP 47800 in the firewall, creates an `e2-small` Debian 12 VM and gives it `deploy/gcp/startup.sh`, which
on every boot installs Docker, fetches the repository, builds the image if the commit changed and runs the container with a restart
policy and the save on the VM's disk (`/var/lib/skyrunner`). The first boot takes a few minutes. `ZONE`, `MACHINE`, `MODE`, `UNLOCKS`,
`MAX_PLAYERS`, `SEED`, `REF` (a branch or tag) and `ALLOW_FROM` (a CIDR to restrict who can connect) are options; the script's header lists them.
It prints the join command and how to update and delete everything.

By hand, the same thing: a VM (any small Linux machine will do; see "Cost and size"), a firewall rule allowing `tcp:47800` to it, and either the Docker steps above or
the systemd unit in `deploy/systemd/skyrunner-server.service` (the project in `/opt/skyrunner`, Godot at `/usr/local/bin/godot`, a `skyrunner`
user, options in `/etc/skyrunner-server.env`). A Google Cloud health check is a plain TCP check on the port.

**Not verified:** `deploy.sh` and `startup.sh` are written against the `gcloud` CLI's documented behaviour and checked for shell syntax, but they have
not been run against a real Google Cloud project (no `gcloud` was available when they were written). The Dockerfile and entrypoint are
exercised by CI, not by hand. Expect to fix a flag or two the first time you run them, and read `gcloud compute instances get-serial-port-output`
if the server does not come up.

## Cost and size

Measured on a developer machine: an hour of server time with the AI flying took about 100 seconds of one core (a few percent of a core), and the
process held about 140 MB. An `e2-small` (2 shared vCPUs, 2 GB) has room to spare; network use per player was not measured. Check Google's
current price list for the VM, the static IP and egress before you leave it running; deleting the VM and the address stops the charges.

## Security

* The protocol is **plain JSON over TCP**: no encryption. The password stops strangers joining; it is sent in the clear, so do not reuse a
  password that matters, and do not run a table you would not play in a public place. If you need privacy, put the server behind a VPN or
  an SSH tunnel and bind it to `127.0.0.1`.
* There is no admin interface and no ban list beyond the listen server's (the host's menu cannot be reached on a dedicated server): to remove a
  player, restart with a new password, or use the firewall's `ALLOW_FROM`.
* A connection must say hello within 10 seconds, a line is at most 1 MB, and `--max-players` caps the table; there is no other rate limiting.
* The status probe tells anyone who can reach the port the server's name, mode, player count, whether it has a password and the game clock.
  It does not tell them the password or anything about a player.

## What the AI does while you are away

With nobody connected the game is the AI playing itself: the aircraft flies jobs (a load that cannot fit is put back, not waited on), the
organisation's AI hires, trades, runs trucks and the Collective, and the law's AI hunts it. In `open` mode that can run the organisation out of
money; it is a sandbox, not a campaign. For a game that stays alive for a group, `--unlocks story` is the one to pick.
