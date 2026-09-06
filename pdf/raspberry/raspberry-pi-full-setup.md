# Raspberry Pi — full headless setup (Wi‑Fi + SSH + VNC)

**Status: verified working.** This is the exact procedure that provisioned this Pi from a
Windows machine, with no monitor and no keyboard ever attached.

| | |
|---|---|
| Image | Raspberry Pi OS **2026-06-18** (pi-gen `stage4` = Desktop, 64-bit) |
| Provisioning | **cloud-init**, NoCloud datasource, `seedfrom: file:///boot/firmware` |
| Network stack | NetworkManager (netplan renderer from `rpi-cloud-init-mods`) |
| Result | `ssh hai1@raspberrypi.local` + RealVNC Viewer → `raspberrypi.local` |

> **Do not follow older guides.** `firstrun.sh`, `custom.toml`, `userconf.txt` and
> `wpa_supplicant.conf` are all obsolete on this image. The only files that matter are
> **`ssh`**, **`network-config`** and **`user-data`** on the boot partition.

---

## Contents

1. [Flash the card](#1-flash-the-card)
2. [Find the boot partition in Windows](#2-find-the-boot-partition-in-windows)
3. [Enable SSH](#3-enable-ssh)
4. [Configure Wi-Fi](#4-configure-wi-fi)
5. [Create the user account](#5-create-the-user-account)
6. [Validate before ejecting](#6-validate-before-ejecting)
7. [First boot](#7-first-boot)
8. [Connect over SSH](#8-connect-over-ssh)
9. [VNC](#9-vnc)
10. [After it works — recommended follow-ups](#10-after-it-works--recommended-follow-ups)
11. [Re-running the provisioning](#11-re-running-the-provisioning)
12. [Troubleshooting](#12-troubleshooting)
13. [Reference — what each setting does](#13-reference--what-each-setting-does)

---

## 1. Flash the card

Write Raspberry Pi OS to the SD card with **Raspberry Pi Imager**.

You can either fill in Imager's **Edit Settings** dialog (it writes the same
`user-data` / `network-config` described below), **or** skip customisation entirely and
write the three files yourself — which is what the rest of this document does. Doing it by
hand works on an already-flashed card and doesn't require rewriting 5 GB.

---

## 2. Find the boot partition in Windows

After flashing, Windows mounts only the small FAT32 partition. The large Linux (ext4)
partition is invisible to Windows — **that is normal, nothing is broken.**

```bash
wmic logicaldisk get deviceid,volumename,filesystem,size
```

Or in PowerShell:

```bash
Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,FileSystem,Size,DriveType
```

Look for the volume labelled **`bootfs`**, FAT32, roughly 512 MB, `DriveType 2` (removable).
On this machine it came up as **`D:`**. Substitute your own letter everywhere below.

A correctly flashed, **never-booted** card shows:

- `cmdline.txt` containing `resize` (not `init=/usr/lib/raspberrypi-sys-mods/firstboot`)
- `user-data`, `meta-data`, `network-config` present, all options commented out
- `initramfs8` / `initramfs_2712` present, and `auto_initramfs=1` in `config.txt`

If `cmdline.txt` has no `resize` and no `init=`, the card has already booted once —
see [section 11](#11-re-running-the-provisioning).

---

## 3. Enable SSH

Create an **empty file named `ssh`** (no extension) in the root of the boot partition.
The `sshswitch` service from `raspberrypi-sys-mods` looks for `/boot/firmware/ssh` and
enables the SSH server when it exists.

```bash
New-Item -ItemType File D:\ssh
```

> Turn on *File Explorer → View → File name extensions* first. If Windows silently saves it
> as `ssh.txt.txt`, it will not be found. (`ssh.txt` is also accepted; `ssh.txt.txt` is not.)

This alone is **not enough to log in** — it starts the SSH daemon, but you still need an
account with a usable password. That is [section 5](#5-create-the-user-account).

---

## 4. Configure Wi-Fi

Replace the entire contents of `D:\network-config`. This is **netplan v2 YAML**:
spaces only, never tabs, and indentation is significant.

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
        "Thinh Hai":
          password: "<your Wi-Fi password>"
```

Key points:

- **Quote the SSID and password.** Required when the SSID contains spaces (`Thinh Hai`) and
  it protects special characters in the password.
- **`optional: true`** on both interfaces stops boot from stalling ~2 minutes waiting for a
  network that may not be there.
- **`regulatory-domain: VN`** sets the Wi-Fi country. Without a country the radio may stay
  `rfkill` soft-blocked and never transmit.
- Hidden network? Add `hidden: true` as a sibling of `password:`.
- **2.4 GHz.** Pi Zero 2 W and Pi 3 have no 5 GHz radio.
- Ethernet is included as a fallback — plug in a cable and NetworkManager DHCPs it
  automatically, no config needed.

---

## 5. Create the user account

### 5.1 Hash the password

Never put a plaintext password in `user-data`. Generate a SHA-512 crypt hash — from
**Git Bash** on Windows:

```bash
openssl passwd -6
```

It prompts twice and prints a string starting with `$6$`. Copy the whole thing.

### 5.2 Write `user-data`

Replace the entire contents of `D:\user-data`. The **first line must be `#cloud-config`** —
cloud-init identifies the file by that header and silently ignores it otherwise.

```yaml
#cloud-config

hostname: raspberrypi
manage_etc_hosts: true

timezone: Asia/Ho_Chi_Minh

users:
  - name: hai1
    gecos: "Hai"
    primary_group: hai1
    groups: [adm, dialout, cdrom, sudo, audio, video, plugdev, games, users, input, netdev, gpio, i2c, spi]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false

chpasswd:
  expire: false
  users:
    - name: hai1
      password: "$6$...paste your hash here..."
      type: hash

ssh_pwauth: true

# Enable the RealVNC server on first boot.
# Needs working internet, because it apt-installs realvnc-vnc-server.
runcmd:
  - [ raspi-config, nonint, do_vnc, 0 ]
```

Why each piece is there:

| Line | Purpose |
|---|---|
| `hostname` + `manage_etc_hosts` | Makes the Pi reachable as `raspberrypi.local` via mDNS and keeps `/etc/hosts` consistent |
| `users:` (explicit, no `- default`) | Creates `hai1` **instead of** the stock `pi`. Listing a user explicitly suppresses the distro default user |
| `groups:` | Grants hardware and admin access. These are cloud-init's own Raspberry Pi OS group set minus `render`/`lpadmin`, which are the two most likely to be missing and would fail `useradd`, leaving you with **no account at all** |
| `sudo: ALL=(ALL) NOPASSWD:ALL` | Writes a `/etc/sudoers.d` entry. Needed so the `runcmd` VNC step can run unattended. See [section 10](#10-after-it-works--recommended-follow-ups) to tighten this afterwards |
| `lock_passwd: false` | Without this, cloud-init creates the account with `!` as the password and **every SSH password is rejected** |
| `chpasswd` + `type: hash` | Sets the password from the hash. `expire: false` stops Linux forcing a password change on first login, which breaks unattended SSH |
| `ssh_pwauth: true` | Turns on `PasswordAuthentication` in `sshd_config` |
| `runcmd` | Runs late in first boot, once networking is up |

Leave `D:\meta-data` exactly as shipped — it only sets `instance_id`.

---

## 6. Validate before ejecting

A YAML typo here costs you a full reflash, so check before pulling the card.

**Line endings.** Windows editors write CRLF, which breaks the parsers. This must print `0`
for both files:

```bash
grep -c $'\r' /d/user-data /d/network-config
```

**YAML syntax:**

```bash
python -c "import yaml; [print(f, yaml.safe_load(open(f, encoding='utf-8')) and 'OK') for f in ['/d/user-data','/d/network-config']]"
```

**Final checklist:**

| File | Expected |
|---|---|
| `ssh` | present, 0 bytes, no extension |
| `network-config` | valid YAML, correct SSID, LF endings |
| `user-data` | starts with `#cloud-config`, `passwd` is a `$6$…` hash, LF endings |
| `meta-data` | untouched |
| `cmdline.txt` | untouched |

Then **Safely Remove Hardware** — FAT32 writes sit in the Windows cache until you eject.

---

## 7. First boot

1. Card into the Pi, power on.
2. **Wait 4–5 minutes.** First boot resizes the root filesystem, runs cloud-init, applies
   everything, and reboots at least once.
3. Do not cut power during this. A half-finished first boot means reflashing.

---

## 8. Connect over SSH

Check it is on the network:

```bash
ping raspberrypi.local
```

Then connect:

```bash
ssh hai1@raspberrypi.local
```

Type `yes` at the host-key prompt, then your password. `ssh` is built into Windows 10/11 —
nothing to install.

### If `.local` does not resolve

mDNS is unreliable on some Windows setups. Get the IP instead:

- **Router admin page** → DHCP client list → look for `raspberrypi`
- Or scan the ARP table for Raspberry Pi MAC prefixes:

```bash
arp -a | Select-String "b8-27-eb|dc-a6-32|e4-5f-01|d8-3a-dd|2c-cf-67"
```

Then:

```bash
ssh hai1@192.168.1.42
```

### After a reflash

The host key changes and SSH refuses to connect with
`REMOTE HOST IDENTIFICATION HAS CHANGED`. Clear the stale entry:

```bash
ssh-keygen -R raspberrypi.local
```

### Confirm the provisioning actually ran

```bash
cloud-init status --long
```

Anything other than `status: done` means something in `user-data` was skipped — the reason
is in the log:

```bash
sudo cat /var/log/cloud-init-output.log
```

---

## 9. VNC

### 9.1 Verify the server

The `runcmd` line should already have done this. Check:

```bash
systemctl status vncserver-x11-serviced
```

If it is not running (usually because the Pi had no internet during first boot), enable it
manually:

```bash
sudo raspi-config nonint do_vnc 0
```

That installs `realvnc-vnc-server` if missing, then enables and starts the service.
Interactive equivalent: `sudo raspi-config` → **3 Interface Options** → **VNC** → **Yes**.

> Current Raspberry Pi OS uses **RealVNC Server**, so RealVNC Viewer is the correct client.
> (Bookworm-era guides that tell you to use `wayvnc` are out of date for this image.)

### 9.2 Set a headless resolution

With no monitor plugged in the Pi has no real display mode and VNC can come up at 640×480:

```bash
sudo raspi-config nonint do_vnc_resolution 1920x1080
```

```bash
sudo reboot
```

> This writes an autostart entry calling `xrandr --fb`, so it applies to an **X11** session.
> If the desktop is running Wayland (labwc) and the resolution is ignored, switch with
> `sudo raspi-config` → **6 Advanced Options** → **Wayland** → **X11**, then reboot.

### 9.3 Connect from Windows

1. Install and open **RealVNC Viewer**.
2. Address bar: `raspberrypi.local` (or the IP). Enter.
3. Accept the identity warning on first connection.
4. Authenticate with the **same credentials as SSH** — user `hai1` and its password.

Default port is **5900**; state it explicitly if needed: `raspberrypi.local:5900`.

---

## 10. After it works — recommended follow-ups

### Update the system

```bash
sudo apt update && sudo apt full-upgrade -y
```

### Switch SSH to key-based login

Generate a key on Windows:

```bash
ssh-keygen -t ed25519 -C "windows-laptop"
```

Install it on the Pi:

```bash
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh hai1@raspberrypi.local "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Once keys work, disable password login on the Pi — edit `/etc/ssh/sshd_config`, set
`PasswordAuthentication no`, then `sudo systemctl restart ssh`.

### Tighten sudo

`NOPASSWD:ALL` was needed so `runcmd` could enable VNC unattended. To require a password
again:

```bash
sudo rm /etc/sudoers.d/90-cloud-init-users
```

Verify you are still in the `sudo` group first, or you will lock yourself out of root:

```bash
groups
```

### Give the Pi a stable address

A **DHCP reservation in your router**, keyed to the Pi's MAC (`ip link show wlan0`), is the
most robust option. To set it on the Pi instead:

```bash
sudo nmcli connection modify "preconfigured" ipv4.method manual ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns "1.1.1.1,8.8.8.8"
```

```bash
sudo nmcli connection up "preconfigured"
```

Replace `preconfigured` with the name from `nmcli connection show`.

### Change Wi-Fi later

Raspberry Pi OS uses NetworkManager — `wpa_supplicant.conf` is no longer the place to edit.

```bash
sudo nmcli device wifi list
```

```bash
sudo nmcli device wifi connect "SSID" password "PASSWORD"
```

Or the text UI:

```bash
sudo nmtui
```

---

## 11. Re-running the provisioning

**cloud-init runs once per instance.** It caches `instance_id` from `meta-data`, so editing
`user-data` and rebooting does **nothing** on a Pi that has already booted.

To force a full re-run, put the card back in Windows and change the last line of
`D:\meta-data` to any new value:

```
instance_id: rpios-image-2
```

cloud-init now sees a "new" instance and reapplies everything on the next boot.

---

## 12. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Pi never appears on the router | Wi-Fi config not applied. Recheck `network-config` for tabs, bad indentation, or a wrong-case SSID |
| Pi is online but SSH is refused | `ssh` file missing or misnamed (`ssh.txt.txt`). Recheck `ssh_pwauth: true` too |
| SSH connects, password always rejected | `lock_passwd: false` missing, or a bad `$6$` hash. Regenerate with `openssl passwd -6` |
| Prompted to change password on first login | `expire: false` missing under `chpasswd` |
| Logged in but `sudo` says user not in sudoers | `useradd` failed on a nonexistent group, so the account was created without them. Remove `render`/`lpadmin` from `groups:` and re-provision |
| Wi-Fi radio soft-blocked | Country not set: `sudo raspi-config nonint do_wifi_country VN` then `sudo rfkill unblock wifi` |
| Pi won't see the home Wi-Fi at all | 5 GHz-only SSID; Pi Zero 2 W / Pi 3 are 2.4 GHz only |
| `.local` never resolves, IP works | Windows mDNS. Install Bonjour or use a DHCP reservation and the IP |
| VNC shows a black or 640×480 screen | Headless resolution not set — [section 9.2](#92-set-a-headless-resolution) |
| VNC service missing entirely | No internet during first boot, so `apt-get install realvnc-vnc-server` failed. Run `sudo raspi-config nonint do_vnc 0` manually |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Card was reflashed: `ssh-keygen -R raspberrypi.local` |
| Edits to `user-data` have no effect | cloud-init already ran — [section 11](#11-re-running-the-provisioning) |
| First boot appears to hang | Normal. Resize + cloud-init + reboot takes several minutes |

---

## 13. Reference — what each setting does

### Files on the boot partition

| File | Read by | Role |
|---|---|---|
| `ssh` | `sshswitch.service` | Enables the SSH server |
| `user-data` | cloud-init (NoCloud) | Users, hostname, timezone, SSH policy, first-boot commands |
| `network-config` | cloud-init → netplan → NetworkManager | Wi-Fi and Ethernet |
| `meta-data` | cloud-init | `instance_id` — the "have I provisioned this already?" marker |
| `cmdline.txt` | kernel | Boot flags. `resize` triggers the first-boot filesystem expansion |
| `config.txt` | firmware | Hardware config (I2C, SPI, camera, display) |

### Useful commands on the Pi

```bash
hostname -I                                # IP addresses
cloud-init status --long                   # did provisioning succeed?
sudo cat /var/log/cloud-init-output.log    # why it did not
systemctl status ssh                       # SSH server
systemctl status vncserver-x11-serviced    # VNC server
nmcli device status                        # network state
sudo nmtui                                 # Wi-Fi text UI
sudo raspi-config                          # full config menu
vcgencmd measure_temp                      # SoC temperature
```

### Upstream sources

- `RPi-Distro/pi-gen` → `stage2/04-cloud-init` — why these files are on the card
- `RPi-Distro/rpi-cloud-init-mods` → `99_raspberry-pi.cfg` — `datasource_list: [NoCloud]`, `seedfrom: file:///boot/firmware`
- `RPi-Distro/raspberrypi-sys-mods` → `sshswitch`
- `RPi-Distro/raspi-config` → `do_vnc`, `do_vnc_resolution`, `do_wifi_country`
- netplan reference — <https://netplan.io/reference>
- cloud-init modules — <https://cloudinit.readthedocs.io/en/latest/reference/modules.html>
