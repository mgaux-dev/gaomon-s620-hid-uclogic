# hid-uclogic with Gaomon S620 (256c:006f) support

The kernel's `hid-uclogic` driver supports the older S620 revision (256c:006d)
but not the newer one (256c:006f). Without it, `hid-generic` binds the tablet
and the pad buttons never show up as a "Tablet Pad" device, so libinput/KWin
can't map them.

The 006f revision has the same firmware (`OEM02_T18e`) and init sequence
(read USB string descriptor 200) as 006d. The patch (`gaomon-s620-006f.patch`):

- adds 256c:006f to the existing Huion init path
- ignores USB interface 1, which on this model is a second pen that goes
  silent in vendor mode (otherwise KDE lists a second, dead tablet)

`61-gaomon-s620.hwdb` fixes the pen resolution. systemd's `60-evdev.hwdb`
has an S620 entry that only fits the generic driver's range and squashes the
vertical axis to ~63 mm with this driver; the correct value is 200 units/mm.

Sources: `drivers/hid/hid-uclogic-*` from linux-stable v7.2.11.

## 1. Check nothing blocks the driver

Userspace tablet drivers sometimes blacklist `hid_uclogic` or tell libinput
to ignore the tablet. Both commands should print nothing:

    grep -rs uclogic /etc/modprobe.d /usr/lib/modprobe.d
    grep -rs 'LIBINPUT_IGNORE_DEVICE' /etc/udev/rules.d /usr/lib/udev/rules.d | grep -i 256c

If they print something, disable whatever installed those files first.

## 2. Test without installing (run from this folder)

    make
    sudo rmmod hid_uclogic 2>/dev/null; sudo insmod ./hid-uclogic.ko

Unplug and replug the tablet, then:

    libinput list-devices | grep -A2 -i gaomon     # expect "GAOMON Gaomon Tablet Pad"
    sudo libinput debug-events                     # press buttons -> TABLET_PAD_BUTTON

## 3. Install permanently with DKMS (rebuilds on kernel updates)

    make clean
    sudo mkdir -p /usr/src/hid-uclogic-gaomon-1.1
    sudo cp -r Makefile dkms.conf *.c *.h usbhid /usr/src/hid-uclogic-gaomon-1.1/
    sudo dkms install hid-uclogic-gaomon/1.1

Upgrading from 1.0: run `sudo dkms remove hid-uclogic-gaomon/1.0 --all` and
`sudo rm -r /usr/src/hid-uclogic-gaomon-1.0` first.

## 4. libwacom entry and resolution fix

    sudo install -Dm644 gaomon-s620.tablet /etc/libwacom/gaomon-s620.tablet
    sudo install -Dm644 /usr/share/libwacom/layouts/gaomon-s620.svg /etc/libwacom/layouts/gaomon-s620.svg
    sudo install -Dm644 61-gaomon-s620.hwdb /etc/udev/hwdb.d/61-gaomon-s620.hwdb
    sudo systemd-hwdb update

Unplug and replug the tablet (or reboot), log out and back in, then map the
buttons in System Settings → Drawing Tablet → Pad.

The driver also creates "Touch Strip" and "Dial" devices (generic Huion v2
templates). The S620 has neither; libinput ignores them, so they are harmless.

## Undo

    sudo dkms remove hid-uclogic-gaomon/1.1 --all
    sudo rm -r /usr/src/hid-uclogic-gaomon-1.1 /etc/libwacom/gaomon-s620.tablet /etc/libwacom/layouts/gaomon-s620.svg /etc/udev/hwdb.d/61-gaomon-s620.hwdb
    sudo systemd-hwdb update

## License

GPL-2.0-or-later, same as the Linux kernel sources this is based on. See `LICENSE`.
