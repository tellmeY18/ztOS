# ztOS

**0.1.0-ALPHA-2** — NixOS, Galaxy S9 (SM-G960N / starlte) and QEMU.

ztOS is a phone operating system built on **NixOS**, with the **ztMETRO**
shell (Windows Phone 8.1's look and motion) on top of wlroots. It includes its
own apps, an updater, a no-profile package store, and an SDK for apps in Python
and Qt. The shell is written in C and drawn with OpenGL. It currently runs on
the Samsung Galaxy S9 (starlte) and in QEMU.

> This is alpha software. The QEMU image is usable today; the starlte image is
> built and internally consistent but has not been boot-tested on a Galaxy S9.
> Open an issue if something fails.

> Your warranty is now void. I am not responsible for bricked devices, dead SD
> cards, or thermonuclear war. Read the [NixOS port notes](nixos/README.md)
> before flashing anything.

**Jump to:** [Quick start](#quick-start) · [Screenshots](#screenshots) ·
[Status](#status) · [What is where](#what-is-where) · [Configuration](#configuration) ·
[The SDK](sdk/README.md) · [License](#license)

## Quick start

### QEMU (recommended)

Download the latest `ztos-qemu-image` artifact from a successful **ztOS QEMU
image** CI run, unzip it, and run it from the devshell:

```sh
unzip ztos-qemu-image.zip -d ztos-qemu
chmod u+w ztos-qemu/rootfs.img
nix develop
ztos-qemu "$PWD/ztos-qemu"
```

The default window is 540x1110. ztMETRO runs at `scale = 1.2`, giving a
450x925 logical area. Login is `ztos` / `ztos`; the graphical session starts
through `greetd`. The mouse is the touchscreen: click to tap, drag to swipe.
The QEMU monitor and serial console are attached to the terminal that launched
`ztos-qemu`.

The image is built to fit its own closure, so `ztos-qemu` grows the raw disk
and filesystem by 8 GiB before boot when it has less than 2 GiB free. Set
`ZTOS_QEMU_GROW=0` to disable that, or `ZTOS_QEMU_GROW=16G` to grow by more.

To change the window size without changing the UI scale:

```sh
ZTOS_QEMU_WIDTH=648 ZTOS_QEMU_HEIGHT=1332 \
  nix develop --command ztos-qemu "$PWD/ztos-qemu"
```

For VNC instead of a native window:

```sh
ZTOS_QEMU_DISPLAY=vnc=:1 nix develop --command ztos-qemu "$PWD/ztos-qemu"
```

Then connect to `localhost:5901`.

### Build the images yourself

`images.qemu` and `images.starlte` are `aarch64-linux` outputs. Build them on
an ARM Linux machine or through the CI workflow:

```sh
nix build .#images.qemu -L
nix develop
ztos-qemu ./result

nix build .#images.starlte -L
sh nixos/tests/image.sh ./result
```

On `aarch64-darwin`, the devshell can run a downloaded image but cannot build
the Linux image locally. Use the CI artifact.

### Install on a Galaxy S9

The starlte bundle contains `rootfs.img`, `boot.img`, `flash.sh`, and
`build.json`:

```sh
nix build .#images.starlte -L
./result/flash.sh
```

The phone must already have its bootloader unlocked and TWRP installed. The
script writes BOOT and USERDATA through `adb` from TWRP and refuses to continue
unless you type `ERASE`. The EFS partitions (IMEI, calibration) are never
touched, and the stock Android partitions must stay on the phone.

## Screenshots

From a Galaxy S9 running ztOS.

<table>
<tr>
<td align="center"><img src="docs/screenshots/start.png" width="230"><br><b>Start</b></td>
<td align="center"><img src="docs/screenshots/app-list.png" width="230"><br><b>App list</b></td>
<td align="center"><img src="docs/screenshots/networking.png" width="230"><br><b>Cellular + SIM</b></td>
<td align="center"><img src="docs/screenshots/sensors.png" width="230"><br><b>Sensors</b> (ZrnDevTest)</td>
<td align="center"><img src="docs/screenshots/about.png" width="230"><br><b>About</b></td>
</tr>
</table>

## What is where

| | |
|---|---|
| `flake.nix` | the NixOS configurations, images, packages, and devshell |
| `nixos/` | the NixOS port: modules, hardware profiles, image builders, scripts, packages |
| `nixos/modules/` | `ztos`, `common`, `session`, `update`, `store`, and the hardware profiles |
| `nixos/configurations/` | `qemu.nix` and `starlte.nix` |
| `nixos/images/` | the QEMU and starlte image bundles |
| `nixos/packages/` | `ztmetro`, `ztos-store-gui`, `ztos-scripts`, `ztos-firmware` |
| `nixos/scripts/` | `run-qemu`, `ztos-run`, `ztos-store`, `ztos-update` |
| `ztmetro/` | the compositor, ZrnMetroCore, bundled apps, daemons |
| `sdk/` | the Python/Qt SDK and app templates |
| `audio/`, `modem/`, `sensors/`, `power/`, `leds/`, `haptics/`, `firmware/`, `camera/`, `bluetooth/`, `media/` | phone hardware support |
| `prebuilts/` | prebuilt starlte kernel, initramfs, boot image, and modules |
| `docs/` | the static website and screenshots |

Legacy Arch Linux ARM paths: `os/`, `rootfs/`, `installer/`, `initramfs/`,
`kernel/`, `scripts/build-arch-root.sh`, `scripts/build-boot.sh`,
`scripts/pacman-proxy.py`, and the `zboot-*` helpers. They remain for reference
only. Do not use them for new installs.

## ztOS's parts

| Name | What it is |
|---|---|
| ztMETRO | the shell: Start, the app list, the action centre, the keyboard, the lock screen |
| ztOSCoreSensorFramework (`ztoscsf`) | starts and watches hardware support, and reports what fails |
| ztOSCoreNetworking | the modem, calls, messages, mobile data, and Wi-Fi joining |
| ztOSCirrusAudio | sound: the audio DSP and the Cirrus speaker amplifiers |
| zrnperfd | power: dynamic boost and core power-down |
| ztos-update | the updater and its update notification |
| Store / ztos-store / ztos-run | install or run Nix packages without adding them to a profile |

## Status

Samsung Galaxy S9 (SM-G960N, `starlte`, Exynos 9810), mainline Linux 7.1.
**Works**: tried and does what it should. **Partial**: some of it works; the
notes say what. **Broken**: tried and does not work. **Not started**: nothing
yet.

### Hardware

| Category | Feature | Status | Notes |
|---|---|---|---|
| Boot | Booting from internal storage (UFS) | Works | Falls back to TWRP after a crash or watchdog reset |
| Boot | Charging while off | Partial | Minimal start until the battery reaches 10%; not yet tried from below 10% |
| Display | Panel, 1440x2960 | Works | DECON scanout |
| Display | Brightness | Works | Manual, and automatic from the light sensor |
| Display | Colour tone | Works | OpenTone in ztoscsf-sensord; 5000–6500 K |
| Input | Touchscreen | Works | S6SY761, multi-touch |
| Input | Power and volume keys | Works | Screen off/on; volume steps |
| Input | Vibration | Works | Strength per kind of touch |
| Input | Notification light | Works | Charging, charged, low battery, rapid boost |
| 3D | GPU | Works | Mali-G72 MC18 through Panfrost, OpenGL ES 3.1 |
| CPU | All 8 cores, frequency scaling | Works | Big cores powered down when idle (zrnperfd) |
| CPU | Suspend / idle power-down | Works | C2 on efficiency cores; big cores offlined on demand |
| Power | Battery and charger | Works | MAX17042 gauge, MAX77705 charger |
| Network | Wi-Fi | Works | BCM4361; join, forget, details, signal |
| Network | Bluetooth | Not started | |
| Network | Mobile data (4G) | Works | Samsung IPC through ztOSCoreNetworking |
| Network | USB networking | Works | 172.16.42.1, plus a serial console |
| Modem | SIM, registration, signal | Works | EFS is never altered |
| Modem | SMS | Partial | Sending works; receiving is untested with a real message |
| Modem | Calls | Partial | Connect, but call audio is not routed |
| Audio | Speaker | Works | ztOSCirrusAudio |
| Audio | Microphone, headphones | Not started | |
| Sensors | Ambient light | Works | Through ztoscsf |
| Sensors | Motion | Partial | Readable in ZrnDevTest; not used by the shell yet |
| Camera / GPS / NFC / fingerprint / Bixby | | Not started | |

### Software

| Category | Feature | Status | Notes |
|---|---|---|---|
| Shell | Start, tiles, app list, search, lock screen | Works | Windows Phone 8.1's look and motion |
| Shell | App switcher, action centre | Works | |
| Shell | On-screen keyboard | Partial | Overlay and lift are written but not yet seen working |
| Shell | Notifications, media banner | Works | freedesktop notifications plus an ntfy push client |
| Shell | Haptics | Works | |
| Power | Dynamic boost | Works | Efficiency cores first, then big cores |
| Apps | Settings | Works | Wi-Fi, mobile, haptics, quick actions, theme |
| Apps | Phone, Messaging, People | Works | |
| Apps | ZrnDevTest, Devices and Services | Works | What the hardware reports |
| Apps | Firefox, Chromium, terminal | Installable | Store app or `sudo ztos-store install firefox`; shown by ztMETRO as windows |
| System | Updates | Works | `ztos-update` |
| System | Package store | Works | Store app, `ztos-store`, and `ztos-run`; installs rebuild the system generation |
| System | NixOS image and flake | Works | QEMU and starlte |
| SDK | ztOS SDK (Python and Qt) | Works | Build, install, run, logs, uninstall |
| Emulator | ztOS in QEMU | Works | Slow; the phone is fully emulated |

## Configuration

The `ztos` NixOS module exposes:

```nix
ztos = {
  enable = true;
  hardware = "qemu";       # "qemu", "starlte", or "generic"
  user = "ztos";
  password = "ztos";       # null leaves the account locked

  ztmetro.enable = true;
  update.enable = true;
  store.enable = true;
  store.bootstrap = true;  # write the initial /etc/nixos flake
};
```

Rebuild a running system from a checkout:

```sh
sudo nixos-rebuild switch --flake .#ztos-qemu
```

On the phone, use `.#ztos-starlte`. On a bootstrapped image, `/etc/nixos` is
generated by `store.bootstrap` and names the configuration after the hostname
(`ztos`):

```sh
sudo nixos-rebuild switch --flake /etc/nixos#ztos
```

### Display and session

ztMETRO reads `~/.config/ztmetro/config`:

```ini
scale = 1.2
lock = off
timeout = 0
```

`scale` is the wlroots output scale; `timeout` is seconds without input before
the screen sleeps (`0` keeps it on). The QEMU configuration creates this file
on first boot when it is missing. Existing images keep their file.

### Updates

`ztos-update` wraps `nixos-rebuild` and reads `/etc/ztos/update.conf`:

```sh
ztos-update check    # refresh the flake and report whether anything moved
ztos-update apply    # rebuild the system
```

The complete system is one NixOS generation, so an update is one rebuild and a
rollback is one generation in the boot menu.

### Packages

The Store app and `ztos-store` install apps by adding them to
`/etc/nixos/packages.nix` and rebuilding the NixOS generation. Nothing is added
to a user profile, so an installed app stays installed across updates and
rollbacks:

```sh
ztos-store search firefox
sudo ztos-store install firefox
ztos-store installed
sudo ztos-store uninstall firefox
```

The Store app uses the same commands and runs the rebuild without a password
prompt. `ztos-store pin` remains for a temporary package kept alive by a GC root
and launched through `ztos-run`:

```sh
sudo ztos-store pin nixpkgs#firefox
ztos-store list
sudo ztos-store remove firefox
ztos-run nixpkgs#firefox -- --private-window
```

## ztMETRO

`ztmetro/` is the compositor and shell: wlroots 0.20 in the manner of Windows
Phone 8.1. Start, the status bar, the nav bar, and the on-screen keyboard are
drawn by the compositor; one app at a time fills the space between the bars.

| Gesture | Does |
|---|---|
| tap a tile | launch the app, or return to it if it is running |
| drag on Start | scroll the tiles |
| nav bar: back | Escape to the app; long press: the next running app |
| nav bar: Start | back to Start; the app keeps running |
| nav bar: search | show or hide the keyboard, until search exists |
| left edge, swipe right | close the app |

**Rendering** is an OpenGL ES quad renderer on the context wlroots creates.
Frames are rendered only while something is damaged or animating. Tiles lean
toward the finger, Start swings away round the left edge on launch, and the
keyboard slides.

**Keyboard**: Windows Phone layout, an Esc / Tab / Ctrl / Alt / arrows row for
terminals, and a symbols page. Keys are real key presses from a virtual
`wlr_keyboard`.

**Action centre**: pulled down from the status bar, with quick actions,
notifications, and an accent bar to push it back up. Wi-Fi and airplane mode go
through `nmcli`.

**ZrnMetroCore** (`ztmetro/core/`): the window, frame clock, scrolling, page
turns, loading dots, and widgets shared by ztMETRO's own apps.

**ZrnDevTest** (`ztmetro/devtest/`): system state, kernel readings, logs, and
what hardware the kernel drives.

**zrnperfd** (`ztmetro/perfd/`): power profiles and screen-driven boost.

**Settings**: Wi-Fi through NetworkManager, display, haptics, quick actions,
theme, performance, and developer tests. It writes
`~/.config/ztmetro/config` and sends the compositor SIGHUP.

**Sound**: the speakers work through `snd-zrn-abox` and PipeWire. Volume keys
drive the PipeWire sink.

**Idle and ambient light**: the shell provides `ext-idle-notify-v1` and uses
the light sensor for automatic brightness and colour temperature.

**App switcher**: hold Start. Open apps become cards; swipe, tap, or throw one
up to close it.

**Fonts**: Segoe WP is used when installed, Selawik otherwise.

**Lock screen**: shown at start and whenever the screen comes back on; push it
up to unlock.

**Checking the look without touching the screen**: `ztmetro --render DIR` and
`ztsettings --render PAGE FILE` draw PNGs with no display.

**Config**: tiles in `~/.config/ztmetro/tiles` (`size | colour | label | icon |
command`); `accent`, `haptics`, `columns`, and `scale` in
`~/.config/ztmetro/config`. The log of the current run is
`~/.local/state/ztmetro.log`.

**Testing without a finger**: `$XDG_RUNTIME_DIR/ztmetro.ctl` takes `tap X Y`,
`down ID X Y`, `move ID X Y`, `up ID`, and `state`, in points, through the same
path as the touchscreen.

## The phone port (starlte)

The starlte image boots the prebuilt mainline 7.1 kernel and initramfs from
`prebuilts/boot/`, with the modules from `prebuilts/modules/` installed under
`/lib/modules/7.1.0-zboot/extra`. The NixOS root filesystem keeps the label
`ZR_ARCH` so the existing boot image can find it.

- **Recovery**: a panic or watchdog reset falls back to TWRP. The bootloader's
  Download mode cannot be overwritten; `prebuilts/` and the stock firmware
  dumps are enough to restore the phone.
- **Partitions**: `flash.sh` writes only BOOT and USERDATA. The stock Android
  partitions must stay for the modem and sensor hub. EFS is never touched.
- **Kernel and device tree**: kernel drivers and device trees under `kernel/`,
  `power/`, `haptics/`, and related directories are GPL-2.0-only. The prebuilt
  boot image is used as-is by the NixOS image.

## The SDK

Third-party apps in Python and Qt: see [sdk/README.md](sdk/README.md).

```sh
ztos-sdk new "Notes"
cd notes
ztos-sdk run
ztos-sdk deploy
```

On a NixOS host, put the SDK tools and Qt in a shell:

```sh
nix shell nixpkgs#python3 nixpkgs#pyside6 nixpkgs#qt6.qtbase
```

The phone gets Qt through Nix; the Store app, `ztos-store`, and `ztos-run` can
supply packages without a profile.

## Troubleshooting

**The window is huge and only part of the UI is visible.** ztMETRO is drawing
at the built-in `scale = 4` because the guest config is missing. Set
`scale = 1.2` in `~/.config/ztmetro/config` and restart the session.

**The session starts locked.** Set `lock = off` and reboot.

**The screen is black for a while on first boot.** The image is growing and
starting NixOS services. Give it a minute.

**`nix build .#images.qemu` fails on a Mac.** It is an `aarch64-linux` output.
Use the CI artifact or a Linux builder. `nix develop` on macOS is for running
the image, not building it.

**The artifact download stalls.** The GitHub artifact API has been unreliable
for this ~1.8 GB artifact; download it from the run page in a browser.

## Legacy Arch Linux ARM tree

The repository still contains the old Arch Linux ARM port (`os/`, `rootfs/`,
`installer/`, `initramfs/`, `kernel/`, and the `zboot-*` scripts). It is kept
for hardware reference and history. It is not built, tested, or supported by
the flake, and its documentation is not a quick start. See
[`nixos/README.md`](nixos/README.md) for the supported path.

## License

* **ztOS userspace and applications** (`nixos/`, `ztmetro/`, `sdk/`, and system
  daemons): [GNU General Public License v3.0 or later](LICENSE)
  (**GPL-3.0-or-later**).
* **Linux kernel drivers and device trees** (`power/`, `haptics/`,
  `third_party/`, kernel patches, and DTS files): GPL-2.0-only, conforming to
  upstream Linux kernel licensing terms.
