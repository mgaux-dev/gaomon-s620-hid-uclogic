# Gaomon S620 pad buttons on Linux

**Patched `hid-uclogic` kernel driver that makes the four pad buttons of the
Gaomon S620 (USB ID `256c:006f`) work with the standard Linux tablet stack,
so you can map them in your desktop's tablet settings, such as KDE Plasma's
Drawing Tablet page. No userspace driver needed.**

Tested on Arch Linux, kernel 7.2.11, KDE Plasma 6.8 (Wayland).

## The problem

The S620 comes in two hardware revisions. The kernel supports the older one
(`256c:006d`) but not the newer one (`256c:006f`), so the newer one falls
back to the generic HID driver. The pen works, but the pad buttons never
appear as a tablet pad, and the desktop can't see them.

Check which one you have:

```bash
lsusb | grep 256c
```

## What this fixes

| Issue | Fix |
| --- | --- |
| Pad buttons not detected | Driver patch: handle `256c:006f` like the older revision (same firmware `OEM02_T18e`, same init sequence) |
| KDE lists a second, dead tablet | Driver patch: ignore USB interface 1, a second pen that goes silent once the tablet is in vendor mode |
| Pen's vertical axis squashed to ~63 mm | `61-gaomon-s620.hwdb`: overrides systemd's resolution entry, which only fits the generic driver |
| libwacom doesn't know the 006f pad | `gaomon-s620.tablet`: adds the 006f pad to the S620 entry |

## Files

| File | Purpose |
| --- | --- |
| `gaomon-s620-006f.patch` | The driver change against upstream Linux v7.2.11 |
| `hid-uclogic-*.c/h`, `hid-ids.h`, `usbhid/` | Patched driver sources (from linux-stable v7.2.11) |
| `Makefile`, `dkms.conf` | Out-of-tree build and DKMS packaging |
| `61-gaomon-s620.hwdb` | Pen resolution fix |
| `gaomon-s620.tablet` | libwacom override |

## Install

### Requirements

Kernel headers for your running kernel, a compiler and DKMS. On Arch:

```bash
sudo pacman -S --needed base-devel linux-headers dkms
```

### 1. Check nothing blocks the driver

Userspace tablet drivers sometimes blacklist `hid_uclogic` or tell libinput
to ignore the tablet. Both commands should print nothing:

```bash
grep -rs uclogic /etc/modprobe.d /usr/lib/modprobe.d
grep -rs LIBINPUT_IGNORE_DEVICE /etc/udev/rules.d /usr/lib/udev/rules.d | grep -i 256c
```

If they print something, disable whatever installed those files first.

### 2. Try it without installing (optional)

```bash
make
sudo rmmod hid_uclogic 2>/dev/null; sudo insmod ./hid-uclogic.ko
```

Unplug and replug the tablet, then check that a pad device shows up:

```bash
libinput list-devices | grep -A2 -i gaomon   # expect "GAOMON Gaomon Tablet Pad"
sudo libinput debug-events                   # press buttons, expect TABLET_PAD_BUTTON
```

The module is gone after a reboot. Use step 3 to keep it.

### 3. Install the driver with DKMS

DKMS rebuilds the module automatically on kernel updates.

```bash
make clean
sudo mkdir -p /usr/src/hid-uclogic-gaomon-1.1
sudo cp -r Makefile dkms.conf *.c *.h usbhid /usr/src/hid-uclogic-gaomon-1.1/
sudo dkms install hid-uclogic-gaomon/1.1
```

Updating from an older version: remove it first with
`sudo dkms remove hid-uclogic-gaomon/<old-version> --all`.

### 4. Install the libwacom and resolution fixes

```bash
sudo install -Dm644 gaomon-s620.tablet /etc/libwacom/gaomon-s620.tablet
sudo install -Dm644 /usr/share/libwacom/layouts/gaomon-s620.svg /etc/libwacom/layouts/gaomon-s620.svg
sudo install -Dm644 61-gaomon-s620.hwdb /etc/udev/hwdb.d/61-gaomon-s620.hwdb
sudo systemd-hwdb update
```

### 5. Load it and set up the buttons

```bash
sudo rmmod hid_uclogic; sudo modprobe hid_uclogic
```

Unplug and replug the tablet, log out and back in, then map the buttons in
**System Settings → Drawing Tablet → Pad**.

## Notes

- The driver also creates "Touch Strip" and "Dial" input devices, from the
  generic Huion v2 templates. The S620 has neither; libinput ignores them, so
  they are harmless.
- The hwdb override assumes this driver is in use. If you go back to the
  stock kernel driver, remove it (see Uninstall).

## Uninstall

```bash
sudo dkms remove hid-uclogic-gaomon/1.1 --all
sudo rm -r /usr/src/hid-uclogic-gaomon-1.1
sudo rm /etc/libwacom/gaomon-s620.tablet /etc/libwacom/layouts/gaomon-s620.svg /etc/udev/hwdb.d/61-gaomon-s620.hwdb
sudo systemd-hwdb update
```

## License

GPL-2.0-or-later, same as the Linux kernel sources this is based on. See
[`LICENSE`](LICENSE).
