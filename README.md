# Enshrouded dedicated server on ARM

Run the Enshrouded dedicated server on an ARM64 Linux VPS (such as Oracle Cloud Ampere free tier), using Hangover.

There is no native Linux server build, so this runs the Windows `enshrouded_server.exe` through Wine, with x86-64 emulation handled by FEX emulation.

A docker build coming soon, to allow doing this on any arm linux server. I want to test it first on a few of my servers.

## Tested on

- Ubuntu 26.04 arm64 (Oracle free tier)
- Ubuntu 24.04 arm64 (Oracle free tier)
- Memory use was about 1.5 GB with one idle player at the very start of the game, long-term not yet tested

## 1. Packages

```bash
sudo apt update && sudo apt install -y curl unzip
```

## 2. Install Hangover

Below instructions are for Ubuntu 26.04
On a different release, change the file name to match your Ubuntu version, for example `hangover_11.16_ubuntu2404_noble_arm64.tar` for 24.04. Builds for 22.04, 24.04, 25.10, 26.04 and Debian 12/13 are listed on the [Hangover releases](https://github.com/AndreRH/hangover/releases) page. 
For a newer Hangover version, change `11.16` in both the tag and the file name.

```bash
mkdir -p ~/hangover && cd ~/hangover
curl -LO https://github.com/AndreRH/hangover/releases/download/hangover-11.16/hangover_11.16_ubuntu2604_resolute_arm64.tar
tar xf hangover_11.16_ubuntu2604_resolute_arm64.tar
sudo apt install -y ./*.deb
```
**Important note:** If you accidentally downloaded the wrong release, delete any files you unpacked first before running the install command or you will end up with a wall of unmet dependencies. This is why we are doing it in its own folder, you can easily delete it and do it again.

## 3. Download the server files

The arm64 build of [DepotDownloader](https://github.com/SteamRE/DepotDownloader/releases) is what I use, steam-cmd would be more complicated to run but would work too I believe.

```bash
curl -LO https://github.com/SteamRE/DepotDownloader/releases/latest/download/DepotDownloader-linux-arm64.zip
unzip DepotDownloader-linux-arm64.zip -d ~/dd
chmod +x ~/dd/DepotDownloader
~/dd/DepotDownloader -app 2278520 -os windows -dir ~/enshrouded
```

To update the game server files in the future, stop the enshrouded service and run the last command again.

## 4. Firewall

Open **UDP port 15637** in two places:

1. The Oracle Cloud ingress rule (security list or network security group) or any other equivalent from your vps provider IF using a VPS with an additional network security layer
2. The server's firewall:

```bash
sudo iptables -I INPUT 1 -p udp --dport 15637 -j ACCEPT
sudo netfilter-persistent save
```
Alternatively allow the port on udp in UFW or other firewall software of your choice. I used UFW (`sudo ufw allow 15637/udp`)

## 5. systemd service

Run this as the normal user that owns `~/enshrouded` (not root). It writes the unit using your own username and home directory:

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

## 6. Configure

Stop the service, edit `~/enshrouded/enshrouded_server.json` (server name, passwords, `slotCount`, and whatever else you want changed), then start it again:

```bash
sudo systemctl stop enshrouded
nano ~/enshrouded/enshrouded_server.json
sudo systemctl start enshrouded
```

Watch the log and wait for `Host_Online` or simply just wait 30-60 seconds. In my experience subsequent starts are very fast.

```bash
tail -f ~/enshrouded/logs/enshrouded_server.log
```

Join from the game via the server browser or direct connect to `<server-ip>:15637`.

## Known issues

### Shutdown is not clean under systemd service

Pressing Ctrl+C when running in a foreground shell shuts the server down cleanly. Under systemd, the game starts its shutdown but hangs at the `Init_Steamworks` step and never exits, so systemd kills it after `TimeoutStopSec`.

- The save system's shutdown steps run before the hang, and the world autosaves regularly, so you should lose at most about 30 seconds of progress. **Contributions to solve this welcome.**
- For a guaranteed clean stop, run the server in a foreground shell and press Ctrl+C instead of using the service. Running it in a tmux shell or screen or similar options could be a decent method.

## Notes

- Back up `~/enshrouded/savegame/` before updating the server or changing versions.
- Only Oracle Ubuntu ARM install has been verified. If this changes I will update the README, but for the time being more testing is required.

## Attribution
I am not associated with Keen Games (the developer) or Enshrouded the game in any way. These are not official instructions and running the dedicated server on Linux is not officially supported. 