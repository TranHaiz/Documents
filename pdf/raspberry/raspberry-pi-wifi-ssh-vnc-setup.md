# Raspberry Pi — Wi‑Fi, SSH and RealVNC setup (headless)

Step-by-step guide for bringing a Raspberry Pi online with **no monitor and no keyboard**,
then reaching it from Windows over **SSH** and **RealVNC Viewer**.

Written against the image currently on the SD card:

| Property | Value |
|---|---|
| Image | Raspberry Pi OS **2026-06-18** (pi-gen `stage4` = Desktop) |
| Boot partition | FAT32, volume label `bootfs` — appears in Windows as a drive letter (e.g. `D:`) |
| First-boot mechanism | **cloud-init**, NoCloud datasource, `seedfrom: file:///boot/firmware` |
| Network stack | NetworkManager (netplan renderer set by `rpi-cloud-init-mods`) |

> **Important — this image is cloud-init based.** Older guides tell you to create
> `firstrun.sh`, `custom.toml`, `userconf.txt` or `wpa_supplicant.conf` on the boot
> partition. Those belong to older Raspberry Pi OS releases. On this image the files
> that matter are **`user-data`**, **`network-config`** and **`meta-data`**, which are
> already present on the boot partition as commented-out templates.

---

## 0. What you need

- The Pi's SD card in a card reader on the Windows machine
- Your Wi‑Fi **SSID** and **password** (2.4 GHz band is safest — Pi Zero 2 W / Pi 3 have no 5 GHz)
- A username and password you want for the Pi
- Windows built-in OpenSSH client (`ssh` in PowerShell — present by default on Windows 10/11)
- [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/) for Windows

---

## 1. Prepare the SD card

There are two ways. **Method A is easier**; Method B is what to do when the card is
already flashed and you don't want to rewrite it.

### Method A — Raspberry Pi Imager (recommended)

1. Open **Raspberry Pi Imager**.
2. Choose device, OS and storage as usual.
3. Click **Next** → when asked *"Would you like to apply OS customisation settings?"*, click **Edit Settings**.
4. On the **General** tab:
   - **Set hostname**: `raspberrypi` (or your own — you will use `<hostname>.local` to reach it)
   - **Set username and password**: e.g. `pi` / your password
   - **Configure wireless LAN**: SSID, password, and **Wireless LAN country = `VN`**
   - **Set locale settings**: time zone `Asia/Ho_Chi_Minh`, keyboard layout `us`
5. On the **Services** tab:
   - Tick **Enable SSH** → select **Use password authentication**
6. **Save** → **Yes** → **Yes** to erase and write.

Imager writes your answers into `user-data` / `network-config` on the boot partition.
Skip to [section 2](#2-first-boot).

### Method B — edit the boot partition by hand

Use this when the card is already flashed. Everything below is edited on the **`bootfs`**
drive (the small ~512 MB FAT32 partition Windows can see; the large Linux partition is
invisible to Windows — that is normal).

#### B.1 Create the `ssh` file

Create an **empty file named `ssh`** (no extension) in the root of `bootfs`.
On first boot the `sshswitch` service sees it and enables the SSH server.

```powershell
New-Item -ItemType File D:\ssh
```

> Make sure Windows didn't silently name it `ssh.txt`. Turn on
> *File Explorer → View → File name extensions* to check. (`ssh.txt` also works,
> but only if it really is named that — `ssh.txt.txt` will not.)

#### B.2 Edit `network-config` (Wi‑Fi)

Replace the contents of `D:\network-config` with the following. This is
**netplan v2 YAML** — indentation is spaces only, never tabs.

```yaml
network:
  version: 2

  ethernets:
    eth0:
      dhcp4: true
      optional: true

  wifis:
    wlan0:
      dhcp4: true
      optional: true
      regulatory-domain: VN
      access-points:
        "YOUR_WIFI_SSID":
          password: "YOUR_WIFI_PASSWORD"
```

- Keep the SSID and password in **double quotes** — this protects special characters.
- For a hidden network add `hidden: true` under the SSID.
- `optional: true` stops boot from stalling ~2 minutes waiting for the network.

#### B.3 Edit `user-data` (user account, SSH, hostname)

Replace the contents of `D:\user-data`. The first line **must** be `#cloud-config`.

```yaml
#cloud-config

hostname: raspberrypi
manage_etc_hosts: true

timezone: Asia/Ho_Chi_Minh

users:
  - name: pi
    gecos: "Raspberry Pi user"
    primary_group: pi
    groups: [adm, dialout, cdrom, sudo, audio, video, plugdev, games, users, input, netdev, gpio, i2c, spi]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    passwd: "PUT_THE_SHA512_HASH_HERE"

ssh_pwauth: true

# Optional: enable the VNC server automatically on first boot.
# Requires working internet, because it apt-installs realvnc-vnc-server.
runcmd:
  - [ raspi-config, nonint, do_vnc, 0 ]
```

**Generating the password hash.** Never put the plain password in `passwd:`.
Produce a SHA-512 crypt hash and paste it in. From Git Bash on Windows:

```bash
openssl passwd -6
```

It prompts twice, then prints a string starting with `$6$`. Paste that whole
string, in double quotes, as the `passwd:` value.

#### B.4 Sanity check before ejecting

| File on `bootfs` | Should be |
|---|---|
| `ssh` | present, empty |
| `network-config` | your SSID + password, no tabs |
| `user-data` | starts with `#cloud-config`, `passwd:` holds a `$6$…` hash |
| `meta-data` | leave as shipped — it just sets `instance_id` |
| `cmdline.txt` | leave alone; it should contain `resize` and `cfg80211.ieee80211_regdom=VN` |

Eject the card safely (**Safely Remove Hardware**) so FAT32 writes are flushed.

---

## 2. First boot

1. Put the card in the Pi, power on.
2. Wait **3–5 minutes**. The first boot resizes the filesystem, runs cloud-init,
   applies your config, and reboots at least once. Do not cut power during this.
3. The green ACT LED settling into occasional blinks (rather than constant activity)
   is a rough sign that it has stopped churning.

---

## 3. Find the Pi on the network

Try these in order from PowerShell.

**a) mDNS hostname** — usually just works:

```powershell
ping raspberrypi.local
```

**b) Router admin page** — log into your router (often `192.168.1.1`) and look at the
DHCP client list for a device named `raspberrypi`.

**c) Scan the ARP table:**

```powershell
arp -a | Select-String "b8-27-eb|dc-a6-32|e4-5f-01|d8-3a-dd|2c-cf-67"
```

Those MAC prefixes are Raspberry Pi Foundation OUIs (older → newer boards).

> If nothing shows up, the Wi‑Fi config didn't take. Jump to [section 7](#7-troubleshooting).

---

## 4. Connect over SSH

```powershell
ssh pi@raspberrypi.local
```

Use the IP address instead if `.local` doesn't resolve:

```powershell
ssh pi@192.168.1.42
```

- The first connection asks to trust the host key → type `yes`.
- Then enter the password you set.

**If you reflash the card later**, the host key changes and SSH refuses to connect with
a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning. Clear the old entry:

```powershell
ssh-keygen -R raspberrypi.local
```

### Optional: key-based login (no password prompt)

```powershell
ssh-keygen -t ed25519 -C "windows-laptop"
```

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi@raspberrypi.local "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

---

## 5. Managing Wi‑Fi after boot

Raspberry Pi OS uses **NetworkManager**. `wpa_supplicant.conf` is no longer the place to edit.

```bash
nmcli device status
nmcli connection show
sudo nmcli device wifi list
sudo nmcli device wifi connect "SSID" password "PASSWORD"
sudo nmcli device wifi connect "SSID" password "PASSWORD" hidden yes
hostname -I
```

Or use the text UI:

```bash
sudo nmtui
```

### Give the Pi a fixed IP

Easiest and most robust is a **DHCP reservation** in your router, keyed to the Pi's MAC
(`ip link show wlan0`). To do it on the Pi instead:

```bash
sudo nmcli connection modify "preconfigured" ipv4.method manual ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns "1.1.1.1,8.8.8.8"
```

```bash
sudo nmcli connection up "preconfigured"
```

Replace `preconfigured` with the connection name shown by `nmcli connection show`.

---

## 6. Enable and connect RealVNC

### 6.1 Enable the VNC server on the Pi

Over SSH:

```bash
sudo raspi-config nonint do_vnc 0
```

That command installs `realvnc-vnc-server` if missing, then enables and starts
`vncserver-x11-serviced`. It needs internet access. The interactive equivalent is
`sudo raspi-config` → **3 Interface Options** → **VNC** → **Yes**.

Confirm it is running:

```bash
systemctl status vncserver-x11-serviced
```

> If you already put the `runcmd:` line in `user-data` (step B.3), this was done for you
> on first boot — just verify with the `systemctl` command.

### 6.2 Set a resolution for headless use

With no monitor attached the Pi has no real display mode, so VNC can come up at a tiny
640×480. Set a virtual size:

```bash
sudo raspi-config nonint do_vnc_resolution 1920x1080
```

```bash
sudo reboot
```

> This writes an autostart entry that calls `xrandr --fb`, so it takes effect on an
> **X11** desktop session. If your desktop is running Wayland (labwc), it may be ignored —
> in that case switch the session with `sudo raspi-config` → **6 Advanced Options** →
> **Wayland** → **X11**, then reboot.

### 6.3 Connect from Windows

1. Open **RealVNC Viewer**.
2. In the address bar type `raspberrypi.local` (or the IP), press Enter.
3. Accept the identity-check warning the first time.
4. Authenticate with the **Pi's username and password** — the same credentials as SSH.

Default port is **5900**. If you ever need it explicitly: `raspberrypi.local:5900`.

---

## 7. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `ping raspberrypi.local` fails, Pi never appears on the router | Wi‑Fi config not applied. Put the card back in Windows and re-check `network-config` for tabs, wrong indentation, or a typo'd SSID. SSID is case-sensitive |
| Pi is on the network, SSH refused | The `ssh` file wasn't picked up. Re-add it to `bootfs`, or check `ssh_pwauth: true` in `user-data` |
| SSH connects but password rejected | The `passwd:` hash is wrong. Regenerate with `openssl passwd -6` — the value must be the full `$6$…` string in quotes |
| Only 5 GHz Wi‑Fi at home, Pi won't join | Pi Zero 2 W and Pi 3 are 2.4 GHz only. Enable a 2.4 GHz SSID on the router |
| Wi‑Fi blocked, `rfkill` shows soft-blocked | Wi‑Fi country not set. `sudo raspi-config nonint do_wifi_country VN`, then `sudo rfkill unblock wifi` |
| `.local` never resolves but the IP works | mDNS issue on Windows. Install Bonjour, or just use the IP with a DHCP reservation |
| VNC connects to a black or 640×480 screen | Headless resolution not set — see step 6.2 |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Card was reflashed. `ssh-keygen -R raspberrypi.local` |
| First boot seems to hang for minutes | Normal on the very first boot (resize + cloud-init + reboot). Give it 5 minutes before intervening |

### Reading the first-boot log

Once you have SSH, cloud-init's own record of what it did is the fastest way to see
why something didn't apply:

```bash
cloud-init status --long
```

```bash
sudo cat /var/log/cloud-init-output.log
```

---

## 8. Command cheat sheet

```bash
hostname -I                                # IP addresses
nmcli device wifi list                     # scan Wi-Fi
sudo nmtui                                 # Wi-Fi text UI
systemctl status ssh                       # SSH server state
systemctl status vncserver-x11-serviced    # VNC server state
sudo raspi-config                          # full config menu
sudo raspi-config nonint do_vnc 0          # enable VNC
sudo raspi-config nonint do_wifi_country VN
cloud-init status --long                   # first-boot provisioning result
vcgencmd measure_temp                      # SoC temperature
sudo apt update && sudo apt full-upgrade -y
```

---

## References

- `RPi-Distro/pi-gen` — `stage2/04-cloud-init` (why `user-data` / `network-config` are on the card)
- `RPi-Distro/rpi-cloud-init-mods` — NoCloud datasource config, `seedfrom: file:///boot/firmware`
- `RPi-Distro/raspberrypi-sys-mods` — `sshswitch` service (the `ssh` file on `bootfs`)
- `RPi-Distro/raspi-config` — `do_vnc`, `do_vnc_resolution`
- netplan reference — <https://netplan.io/reference>
- cloud-init modules — <https://cloudinit.readthedocs.io/en/latest/reference/modules.html>
