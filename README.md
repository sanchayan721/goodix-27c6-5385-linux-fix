# Goodix HTK32 Fingerprint Sensor Fix for Ubuntu and Debian — Dell XPS 13 7390

**If you own a Dell XPS 13 7390 running Ubuntu or Debian and your fingerprint reader has never worked, this guide is for you.**

This fixes the Goodix HTK32 fingerprint sensor (`27c6:5385` / `27c6:5395`) on Ubuntu 24.04 (Noble) and Debian 12 (Bookworm). The sensor has been broken on Linux for years because:

1. Ubuntu/Debian packaged `libfprint` has **no driver** for this specific USB ID.
2. The Linux `cdc_acm` kernel module **hijacks the device** as a modem on every boot, blocking libfprint from claiming it.

Both problems are fixed by this guide.

---

## Affected Hardware

| Device | USB ID |
|--------|--------|
| Dell XPS 13 7390 | `27c6:5385` |
| Dell XPS 13 7390 2-in-1 | `27c6:5385` |
| Dell XPS 15 9570 | `27c6:5395` |

Check if you have this sensor:
```bash
lsusb | grep -E '27c6:(5385|5395)'
```

Expected output:
```
Bus 001 Device 004: ID 27c6:5385 Shenzhen Goodix Technology Co.,Ltd. HTMicroelectronics
```

---

## Why Ubuntu and Debian Packages Don't Work

Running `fprintd-list $USER` on a stock Ubuntu/Debian installation will show:

```
found 1 devices
Device at '/net/reactivated/Fprint/Device/0'
Using device /net/reactivated/Fprint/Device/0
User ... has no fingers enrolled for No device available.
```

Or `fprintd-enroll` reports **"No devices available"** even though `lsusb` shows the sensor.

**Root cause 1 — Missing driver:** Ubuntu/Debian `libfprint-2-2` is built without support for USB ID `27c6:5385`. The TOD plugin directory (`/usr/lib/x86_64-linux-gnu/libfprint-2/tod-1`) contains no plugin for this sensor. No official Ubuntu or Debian package provides one.

**Root cause 2 — `cdc_acm` modem conflict:** The Goodix sensor exposes a USB CDC (Communications Device Class) descriptor. Linux's `cdc_acm` driver sees this and claims the device as a serial/modem device on every boot. While `cdc_acm` holds it, libfprint gets "Resource busy" and cannot open the sensor.

---

## Solution Overview

1. Build [`AndyHazz/goodix53x5-libfprint`](https://github.com/AndyHazz/goodix53x5-libfprint) — a patched libfprint v1.94.10 with a community-written driver for this exact sensor.
2. Install the patched `libfprint-2.so` over the system library.
3. Deploy a udev rule that automatically unbinds `cdc_acm` on boot.

---

## Automated Install (Recommended)

> **Supported:** Ubuntu 22.04/24.04 and Debian 12 (Bookworm).

```bash
git clone https://github.com/YOUR_USERNAME/goodix-htk32-ubuntu-fix.git
cd goodix-htk32-ubuntu-fix
chmod +x install.sh
./install.sh
```

The script will:
- Verify your sensor is present (`27c6:5385` or `27c6:5395`)
- Install all build dependencies
- Install runtime packages (`fprintd`, `libpam-fprintd`)
- Clone libfprint v1.94.10 and the Goodix driver
- Patch, build, and install the library
- Deploy the udev rule for `cdc_acm`
- Restart `fprintd`

You do **not** need to reboot, but a reboot ensures the udev rule fully takes effect. After the script completes, follow the [Enrollment](#enrollment) section.

### Installer Structure

The installer is split into focused modules to keep maintenance simple:

- `install.sh` - top-level orchestrator
- `scripts/lib/common.sh` - logging helpers and banner
- `scripts/lib/config.sh` - shared variables and dependency list
- `scripts/lib/preflight.sh` - root/sensor/distro/apt checks
- `scripts/lib/deps.sh` - apt dependency installation
- `scripts/lib/source.sh` - clone/update sources + patch integration
- `scripts/lib/build.sh` - configure/compile/install/verification for libfprint
- `scripts/lib/udev.sh` - udev rule deployment and cdc_acm unbind
- `scripts/lib/verify.sh` - post-install checks and next-step output

---

## Manual Install

If you prefer to understand each step or the automated script doesn't apply to your distro:

### 1. Install Build Dependencies

```bash
sudo apt update
sudo apt install -y \
    fprintd libpam-fprintd \
    git meson ninja-build pkg-config \
    libglib2.0-dev libgusb-dev \
    libssl-dev libopencv-dev \
    gobject-introspection libgirepository1.0-dev \
    libcairo2-dev libgudev-1.0-dev \
    python3-gi-cairo gir1.2-glib-2.0
```

### 2. Clone the Repos

```bash
mkdir -p ~/fpfix && cd ~/fpfix

# Patched libfprint source
git clone https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint && git checkout v1.94.10 && cd ..

# Goodix53x5 driver
git clone https://github.com/AndyHazz/goodix53x5-libfprint.git
```

### 3. Apply the Driver

```bash
cd goodix53x5-libfprint
./install.sh ../libfprint
```

Then apply the meson build integration patch:

```bash
cd ../libfprint
patch -p1 < ../goodix53x5-libfprint/meson-integration.patch
```

### 4. Build and Install

```bash
meson setup builddir
meson compile -C builddir -j$(nproc)
sudo meson install -C builddir
```

### 5. Deploy the udev Rule

```bash
sudo cp ../goodix53x5-libfprint/91-goodix-fingerprint.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### 6. Restart fprintd

```bash
sudo systemctl restart fprintd
```

---

## Enrollment

After installation, enroll a fingerprint using GNOME Settings or the command line.

### GNOME Settings (Recommended)

Open **Settings → Users → Fingerprint Login** and follow the on-screen prompts. This is the easiest method and avoids D-Bus claim conflicts.

### Command Line

```bash
fprintd-enroll -f right-index-finger $USER
```

Follow the prompts. You will be asked to place your finger on the sensor 8 times. If you get `Device was already claimed`, GNOME Settings may already hold the device — use the GUI instead, or:

```bash
# Stop GNOME session services temporarily and try again
sudo systemctl restart fprintd
fprintd-enroll -f right-index-finger $USER
```

Verify enrollment worked:
```bash
fprintd-verify $USER
```

---

## Enable Fingerprint Login (PAM)

Once enrolled, enable fingerprint authentication system-wide:

```bash
sudo pam-auth-update
```

Select **"Fingerprint authentication"** in the menu and confirm. This enables fingerprint for `sudo`, the lock screen, TTY login, and GDM.

---

## Caveats and Maintenance

### Library gets overwritten on apt upgrade

The installed `libfprint-2.so` replaces the distro package file. When your distro releases a `libfprint-2-2` update, `apt upgrade` will overwrite it and your fingerprint reader will stop working again.

**Fix:** Re-run `install.sh` after any `libfprint-2-2` package upgrade, then restart fprintd.

To get notified when libfprint is upgraded, you can pin or hold the package:
```bash
sudo apt-mark hold libfprint-2-2
```

Note: holding the package prevents security updates for libfprint — weigh that tradeoff.

### Enrollment data persists across reinstalls

Fingerprint templates are stored in `/var/lib/fprint/` and survive library reinstalls. You don't need to re-enroll after updating the library.

---

## Troubleshooting

### "No devices available" after install

Check if `cdc_acm` is still bound:
```bash
ls /sys/bus/usb/drivers/cdc_acm/ | grep "1-"
```

If you see entries, the udev rule may not have run yet. Either reboot or manually unbind:
```bash
# Find your device's interface IDs first
lsusb -t | grep -A3 '27c6'
# Then unbind (replace X:Y with your interface IDs)
echo "1-X:1.0" | sudo tee /sys/bus/usb/drivers/cdc_acm/unbind
echo "1-X:1.1" | sudo tee /sys/bus/usb/drivers/cdc_acm/unbind
sudo systemctl restart fprintd
```

### "GTLS identity verification failed" in fprintd logs

This was seen during initial driver load before a reboot and typically resolves after reboot. If it persists, the PSK (Pre-Shared Key) negotiation is failing — check that the patched libfprint is actually installed:

```bash
strings /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 | grep -c 'goodix53x5'
```

Should return a non-zero number. If it returns `0`, the patched library wasn't installed — re-run `sudo meson install -C builddir` from the libfprint build directory.

### Build fails with missing dependency

If `meson setup` fails, read the error message carefully — it will name the missing package. Common extras needed on some Ubuntu/Debian versions:

```bash
sudo apt install libsdl-pango-dev  # if cairo-related build fails
sudo apt install valac             # if vala bindings are needed
```

### fprintd shows device but enrollment is stuck

Watch the fprintd journal in a separate terminal while enrolling:
```bash
sudo journalctl -fu fprintd
```

---

## How It Works (Technical)

The Goodix HTK32 is a 108×88 pixel capacitive press-type sensor. The driver:

1. **Handshake**: PSK exchange and GTLS (a TLS-like protocol) handshake with the sensor firmware.
2. **Configuration**: Uploads sensor config, performs FDT (Finger Detection Threshold) calibration.
3. **Capture**: Detects finger via FDT events, captures and decrypts the 12-bit capacitive image (AES/GEA encryption).
4. **Matching**: Uses **SIGFM** (SIFT-based Fingerprint Matching via OpenCV) — SIFT keypoints with CLAHE contrast enhancement, Lowe's ratio test, and pairwise geometric verification.

Traditional minutiae-based matching struggles on a sensor this small (108×88). SIGFM's keypoint approach works reliably.

---

## Credits

- **Driver implementation**: [`AndyHazz/goodix53x5-libfprint`](https://github.com/AndyHazz/goodix53x5-libfprint)
- **SIGFM matching library**: [`goodix-fp-linux-dev/sigfm`](https://github.com/goodix-fp-linux-dev/sigfm) by Matthieu Charette, Natasha England-Elbro, and Timur Mangliev
- **Protocol reverse-engineering**: [`goodix-fp-linux-dev`](https://github.com/goodix-fp-linux-dev)

---

## License

The install script and documentation in this repository are released under [CC0 (public domain)](https://creativecommons.org/publicdomain/zero/1.0/).

The driver itself (`AndyHazz/goodix53x5-libfprint`) is LGPL-2.1-or-later, same as libfprint.
