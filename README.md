# Enshrouded dedicated server on ARM

Run the Enshrouded dedicated server on an ARM64 Linux server (such as the Oracle Cloud Ampere free tier) using [Hangover](https://github.com/AndreRH/hangover) (Wine for ARM64 with FEX x86-64 emulation).

There is no native Linux server build, so this runs the Windows `enshrouded_server.exe` through Wine, with the x86-64 code emulated.

## Table of Contents

- [Install](#install)
  - [Method A: bare metal with systemd](#method-a-bare-metal-with-systemd)
  - [Method B: bare metal in the foreground or background (no systemd)](#method-b-bare-metal-in-the-foreground-or-background-no-systemd)
  - [Method C: Docker](#method-c-docker)
- [Configuration](#configuration)
- [Updating](#updating)
- [Performance](#performance)
- [Known issues](#known-issues)
- [Notes](#notes)
- [Attribution](#attribution)

## Tested on

- Ubuntu 26.04 arm64 (Oracle free tier)
- Ubuntu 24.04 arm64 (Oracle free tier)
- Memory use was about 1.5 GB with one idle player at the very start of the game, long-term not yet tested

## Install

### Initial prep (Methods A and B)

#### 1. Packages

```bash
sudo apt update && sudo apt install -y curl unzip
```

#### 2. Install Hangover

Below instructions are for Ubuntu 26.04.
On a different release, change the file name to match your Ubuntu version, for example `hangover_11.16_ubuntu2404_noble_arm64.tar` for 24.04 (in both the `curl` and `tar` lines). Builds for 22.04, 24.04, 25.10, 26.04 and Debian 12/13 are listed on the [Hangover releases](https://github.com/AndreRH/hangover/releases) page.
For a newer Hangover version, change `11.16` in both the tag and the file name.

```bash
mkdir -p ~/hangover && cd ~/hangover
curl -LO https://github.com/AndreRH/hangover/releases/download/hangover-11.16/hangover_11.16_ubuntu2604_resolute_arm64.tar
tar xf hangover_11.16_ubuntu2604_resolute_arm64.tar
sudo apt install -y ./*.deb
cd ~
```

**Important note:** If you accidentally downloaded the wrong release, delete the whole `~/hangover` folder before trying again, or you will end up with a wall of unmet dependencies. This is why we use a separate folder.

Check it worked:

```bash
wine --version
```

#### 3. Download the server files

The arm64 build of [DepotDownloader](https://github.com/SteamRE/DepotDownloader/releases) is what I use. SteamCMD would be more complicated to run but would probably work too.

```bash
curl -LO https://github.com/SteamRE/DepotDownloader/releases/latest/download/DepotDownloader-linux-arm64.zip
unzip DepotDownloader-linux-arm64.zip -d ~/dd
chmod +x ~/dd/DepotDownloader
~/dd/DepotDownloader -app 2278520 -os windows -dir ~/enshrouded
```

#### 4. Firewall

Open **UDP port 15637** in two places:

1. The Oracle Cloud ingress rule (security list or network security group), or the equivalent from your VPS provider, if it has an additional network security layer.
2. The server's own firewall:

```bash
sudo iptables -I INPUT 1 -p udp --dport 15637 -j ACCEPT
sudo netfilter-persistent save
```

Alternatively allow the port in UFW or another firewall of your choice (`sudo ufw allow 15637/udp`).

### Method A: bare metal with systemd

Complete the [initial prep](#initial-prep-methods-a-and-b) first.

```bash
sudo tee /etc/systemd/system/enshrouded.service > /dev/null <<EOF
[Unit]
Description=Enshrouded Dedicated Server
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/enshrouded
Environment=WINEPREFIX=$HOME/.wine-ens
Environment=WINEDEBUG=-all
ExecStart=/usr/bin/wine ./enshrouded_server.exe
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=20
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

Then enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now enshrouded
```

The first launch creates the Wine prefix, so it takes longer than usual.

Useful commands:

```bash
sudo systemctl status enshrouded
sudo systemctl restart enshrouded
sudo systemctl start enshrouded
sudo systemctl stop enshrouded
tail -f ~/enshrouded/logs/enshrouded_server.log
```

Wait for `Host_Online` in the log (30 to 60 seconds at first, subsequent starts are much faster), then join. See [Known issues](#known-issues) for the shutdown limitation, it's likely not a big deal.

### Method B: bare metal in the foreground or background (no systemd)

Complete the [initial prep](#initial-prep-methods-a-and-b) first.

#### Foreground

This is the simplest way and the only one confirmed to shut down cleanly (but other methods have **not** been shown to cause any save corruption!). Ctrl+C stops the server properly.

```bash
cd ~/enshrouded
WINEPREFIX=~/.wine-ens WINEDEBUG=-all DISPLAY= wine ./enshrouded_server.exe
```

The server stops when you close the terminal or SSH session. To keep it running after you disconnect, use a background method below.

#### Background with tmux or screen

A terminal multiplexer keeps the foreground process alive after you disconnect, and you can reattach to press Ctrl+C for a clean stop.

```bash
sudo apt install -y tmux
tmux new -s enshrouded
cd ~/enshrouded
WINEPREFIX=~/.wine-ens WINEDEBUG=-all DISPLAY= wine ./enshrouded_server.exe
```

Detach with `Ctrl+b` then `d`. Reattach with `tmux attach -t enshrouded`, and stop the server with `Ctrl+C`. `screen` works the same way if you prefer it.

```bash
cd ~/enshrouded
WINEPREFIX=~/.wine-ens WINEDEBUG=-all DISPLAY= setsid nohup wine ./enshrouded_server.exe > ~/enshrouded/console.log 2>&1 &
```

To stop it from separate shell, send SIGINT to the game process and watch the log for `Close Log file` if you want to be extra sure:

```bash
pkill -INT -x enshrouded_serv
tail -f ~/enshrouded/logs/enshrouded_server.log
```

These and any other commands in the repo can be [aliased](https://ss64.com/bash/alias.html) for easy use in your shell

### Method C: Docker

#### Install

```bash
git clone https://github.com/kellegram/enshrouded-arm-server.git
cd enshrouded-arm-server
mkdir -p ~/enshrouded-arm
docker compose up -d --build
```

Server files, saves and config are stored in `~/enshrouded-arm`, outside the repo folder.

On the first start it downloads the server files (a few GB) and creates the Wine prefix, so allow some time, dependant on the server's specs and download speed. 
Wait for `Host_Online` in the log to know if the server is ready to accept players (`docker compose logs -f`)

#### useful commands

With expectation that you are currently inside the folder containing `docker-compose.yml` file
```bash
docker compose logs -f          # console output
docker compose stop             # stop the container (and server)
docker compose start
docker compose restart
docker compose down             # remove the container, keeps ~/enshrouded-arm
docker compose up -d --build    # rebuild after changing the Dockerfile
```

The Hangover and DepotDownloader versions are fixed at build time. To use another Hangover version, change `HANGOVER_VERSION` in the `Dockerfile` (or pass `--build-arg HANGOVER_VERSION=...`) and rebuild.


#### Docker settings

| Setting | Default | Meaning |
|---------|---------|---------|
| `UPDATE_ON_START` > `environment` | `true` | Check for and install server updates every time the container starts. Set to `false` to skip. |
| Port | `15637:15637/udp` | If you change `queryPort` in the server config, change both sides to match. |
| `stop_grace_period` | `30s` | How long Docker waits for the server to stop before killing it. |

Server settings (name, passwords, slots, gameplay) are in the game's own config file, see [Configuration](#configuration).

## Configuration

The server writes a config file the first time it starts. Start it once, stop it, edit the file, and start it again. Always stop the server before editing, because it may overwrite the file.

| Method | Config file |
|--------|-------------|
| A, B (bare metal) | `~/enshrouded/enshrouded_server.json` |
| C (Docker) | `~/enshrouded-arm/server/enshrouded_server.json` |

```bash
# Method A
sudo systemctl stop enshrouded
nano ~/enshrouded/enshrouded_server.json
sudo systemctl start enshrouded

# Method C
docker compose stop
nano ~/enshrouded-arm/server/enshrouded_server.json
docker compose start
```

**Passwords:** the generated config contains random passwords for the `Admin`, `Friend`, `Guest` and `Visitor` groups. Players pick a group by entering its password when joining. Change them before inviting anyone, and do not share your config file publicly.

Group permissions are `canKickBan`, `canAccessInventories`, `canEditWorld`, `canEditBase`, `canExtendBase` and `reservedSlots`.

Join from the game via the server browser, or by direct connect to `<server-ip>:15637`.

## Updating

Stop the server, back up `savegame/`, then download the files again with the same DepotDownloader command.

- **Bare metal:** `sudo systemctl stop enshrouded` (or stop your foreground process), then `~/dd/DepotDownloader -app 2278520 -os windows -dir ~/enshrouded`, then start it again.
- **Docker:** with `UPDATE_ON_START` set to `true`, run `docker compose restart`.

## Performance

### Enable ntsync (Methods A and B)

Wine can use the kernel's `ntsync` driver (kernel 6.14 or newer) for synchronisation instead of routing it through `wineserver`.

First, verify that your server supports ntsync
```bash
sudo modprobe ntsync
ls -l /dev/ntsync
```
You should see the directory as output. If you get an error, your kernel might not have ntsync support. There are guides online on how to verify this.

The command below will persist the loading of the module on reboots:
```bash
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf
```

To confirm, this should list `ntsync` entries after rebooting the server (and while the game server is running):

```bash
sudo ls -l /proc/$(pgrep -x wineserver | head -1)/fd | grep ntsync
```

## Known issues

### Shutdown is not clean under systemd

Pressing Ctrl+C when running in a foreground shell shuts the server down cleanly. Under systemd, the game starts its shutdown but hangs at the `Init_Steamworks` step and never exits, so systemd kills it after `TimeoutStopSec`.

- The save system's shutdown steps run before the hang, and the world autosaves regularly, so you should lose at most about 30 seconds of progress. **Contributions to solve this welcome.**
- No negative consequences have been observed so far and based on logs, it hangs on one of the last destructors that cleans up data from that run
## Notes

- Back up `savegame/` before updating the server or changing versions.
- Only Oracle Ubuntu ARM installs have been verified. If this changes I will update the README, but for the time being more testing is required.

## Attribution

I am not associated with Keen Games (the developer) or Enshrouded the game in any way. These are not official instructions and running the dedicated server on Linux is not officially supported.
