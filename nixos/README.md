# ztOS on NixOS

This is ztOS. NixOS builds the complete userspace, ztMETRO, the systemd
services, the updater, the package store, and the phone and QEMU images from
the same flake. The old Arch Linux ARM flow remains in the repository only as
hardware reference and history; it is not a supported target.

The QEMU image is usable today. The starlte image is built and internally
consistent, but it has **not** been boot-tested on a Galaxy S9 yet.

## What is in the flake

| Output | What it is |
|---|---|
| `nixosConfigurations.ztos-qemu` | the QEMU/aarch64 NixOS system |
| `nixosConfigurations.ztos-starlte` | the Galaxy S9 NixOS system |
| `nixosConfigurations.ztos-flame` | the Pixel 4 NixOS system |
| `images.qemu` | direct-boot QEMU bundle: `Image`, `initrd`, `rootfs.img`, `cmdline`, `README` |
| `images.starlte` | phone bundle: `rootfs.img`, `boot.img`, `flash.sh`, `build.json` |
| `images.flame` | Pixel 4 bundle: `rootfs.img`, `uboot.img`, `flash.sh`, `build.json`, `README` |
| `packages.ztmetro` | the shell, apps, helpers, and their systemd units |
| `devShells.default` | QEMU, image, and Android flashing tools; also works on `aarch64-darwin` |

The NixOS modules live in `nixos/modules/`. The hardware profiles are
`nixos/modules/hardware/qemu.nix`, `starlte.nix` and `flame.nix`. The system
configurations are in `nixos/configurations/`.

## Try it in QEMU

### Use a CI-built image

The image is built on GitHub's `ubuntu-24.04-arm` runner. Open the latest
successful **ztOS QEMU image** run, download the `ztos-qemu-image` artifact,
and unzip it. The directory will contain the four files listed above.

```sh
unzip ztos-qemu-image.zip -d ztos-qemu
chmod u+w ztos-qemu/rootfs.img
cd /path/to/ztOS
nix develop
ztos-qemu "$PWD/ztos-qemu"
```

The default window is a 540x1110 phone-shaped QEMU display. The shell runs at
1.2x, giving a 450x925 logical layout. The first boot can take a minute or two;
later boots are faster.

Login on the serial console is `ztos` / `ztos`. The graphical session starts
automatically through `greetd`. The mouse is the touchscreen: click to tap,
drag to swipe. The QEMU monitor and serial console are attached to the terminal
that launched `ztos-qemu`.

The image is built to fit its own closure. Before boot, `ztos-qemu` grows the
raw disk and ext4 filesystem by 8 GiB when there is less than 2 GiB free, so
packages can be installed without manual resizing. Set `ZTOS_QEMU_GROW=0` to
disable it, or give another size such as `ZTOS_QEMU_GROW=16G`. The guest also
runs `resize2fs` at boot, so an image enlarged with `qemu-img resize` fills the
new space automatically.

### Build the image yourself

`images.qemu` is an `aarch64-linux` output. Build it on an ARM Linux machine
or in the CI workflow:

```sh
nix build .#images.qemu -L
nix develop
ztos-qemu ./result
```

The build does not need KVM. It uses the NixOS ext4 builder to create
`rootfs.img` and puts the kernel and initrd beside it, so the image is booted
directly with `-kernel`/`-initrd` instead of through EFI or a bootloader.

On `aarch64-darwin` the devshell runs QEMU with HVF, but the Linux image
itself cannot be built locally. Use the CI artifact. On Linux, `ztos-qemu`
uses KVM when `/dev/kvm` is writable and falls back to TCG otherwise.

### Display and sizing

The launcher accepts:

```sh
ZTOS_QEMU_WIDTH=648 ZTOS_QEMU_HEIGHT=1332 \
  nix develop --command ztos-qemu /path/to/image
```

540x1110 is the default and gives a 450x925 logical shell at `scale = 1.2`.
Increase the physical size for a larger window; change `scale` to change the UI
size. The original 360x740 layout is 432x888 at `scale = 1.2` or 540x1110 at
`scale = 1.5`.

```sh
# inside the guest, as the ztOS user
$EDITOR ~/.config/ztmetro/config
```

```ini
scale = 1.2
lock = off
timeout = 0
```

`lock = off` disables locking after idle; `timeout = 0` keeps the screen on.
The QEMU configuration creates this file on first boot if it is missing, so a
fresh image starts unlocked. Existing images keep their existing file.

For a VNC window instead of a native window:

```sh
ZTOS_QEMU_DISPLAY=vnc=:1 nix develop --command ztos-qemu /path/to/image
```

Then connect to `localhost:5901`. Any value accepted by QEMU's `-display`
option works.

## Galaxy S9 (starlte)

```sh
nix build .#images.starlte -L
ls result
# boot.img  build.json  flash.sh  rootfs.img
```

`flash.sh` writes `BOOT` and `USERDATA` through `adb` from TWRP. It refuses to
continue unless you type `ERASE`:

```sh
./result/flash.sh
```

The phone must already have its bootloader unlocked and TWRP installed; the
NixOS image does not replace the bootloader or RECOVERY. The EFS partitions
are not touched.

What the starlte image still depends on:

- `prebuilts/boot/ztos-starlte-boot.img` — the mainline 7.1 kernel, initramfs,
  uniLoader, and Samsung boot image. This is still a prebuilt artifact, not a
  Nix derivation.
- `prebuilts/modules/` — copied into the rootfs as
  `/lib/modules/7.1.0-zboot/extra`.
- The boot image's command line and module layout, which expect the root
  filesystem at the `ZR_ARCH` label. The NixOS rootfs keeps that label so the
  existing boot image can find it.

The starlte configuration deliberately disables the NixOS bootloader, initrd,
and kernel-module machinery: the phone boots the prebuilt kernel, not a NixOS
stage-1. It also disables the ZFS filesystem module, because that would pin a
different kernel package.

This path is ready for hardware testing, not a daily driver. If the phone
fails to boot, it should still fall back to TWRP. Keep the stock partitions;
see the [main README](../README.md#troubleshooting).

## Pixel 4 (flame)

```sh
nix build .#images.flame -L
ls result
# build.json  flash.sh  README  rootfs.img  uboot.img
```

The Pixel 4 cannot boot a mainline kernel from its stock ABL, so the image
follows the boot chain the Nura (formerly postmarketOS) `device-google-flame`
port uses:

```
ABL -> U-Boot in boot_a -> extlinux.conf in the userdata ext4 -> Image + dtb
```

`flash.sh` puts U-Boot in `boot`, writes the root filesystem to `userdata`, and
asks for `ERASE` first, because that overwrites Android and everything in its
storage. Every other partition is left alone, so a stock factory image can put
Android back.

What the flame image is made of:

- `nixos/packages/linux-flame.nix` — the SM8150 kernel fork the Nura port uses
  (`linux-postmarketos-qcom-sm8150`), with its own configuration. It is the only
  tree with the Pixel 4 panel (LG LH568WF3-ED01 / NT37280) and touch drivers;
  upstream still has no `sm8150-google-flame.dts`.
- `nixos/packages/uboot-flame.nix` — U-Boot for `sm8150-google-flame`, packed
  into `uboot.img` with the device tree appended.
- `nixos/packages/firmware-flame.nix` — WCN3990, ADSP/CDSP/modem, and the signed
  Adreno 640 zap shader.
- The kernel has UFS and ext4 built in, so there is no initramfs: the kernel
  mounts `userdata` directly and firmware is baked into the image's
  `/lib/firmware` for the GPU probe.

Status: the image builds, but it has not been run on a phone yet. Expect a
serial console (`ttyMSM0`) or a framebuffer console before a ztMETRO session;
the GPU, panel and touch bring-up is the remaining work. See the Nura wiki page
for the hardware that still needs drivers.

## Configuration

The `ztos` module exposes:

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

`ztos.update` wraps `nixos-rebuild`; it reads `/etc/ztos/update.conf` and
defaults to the flake at `/etc/nixos` and the configuration named after the
hostname. `ztos.store` provides the Store app, `ztos-store`, and `ztos-run`.
`ztos-store install` adds an attribute to `/etc/nixos/packages.nix` and rebuilds
the generation; `uninstall` removes it. There is no user profile, so installed
apps survive updates and rollbacks. `store.bootstrap` writes a small
`/etc/nixos/flake.nix` on first activation and keeps the source in a GC root;
the QEMU and starlte configurations enable it. `pin`/`remove` remain for
temporary apps kept by a GC root and launched through `ztos-run`.

To rebuild a running system from a checkout:

```sh
sudo nixos-rebuild switch --flake .#ztos-qemu
```

On the phone, use `.#ztos-starlte`. On a bootstrapped image, `/etc/nixos` is
generated by `store.bootstrap` and names the configuration after the hostname
(`ztos`):

```sh
sudo nixos-rebuild switch --flake /etc/nixos#ztos
```

## Migration status

Ported to NixOS:

- ztMETRO, its apps, the OpenGL shell, and `ztmetro-session`
- greetd session, PipeWire, NetworkManager, polkit, fonts, udev rules
- ztOS hardware services and overlay files
- the updater, the Store app, `ztos-run`, and `ztos-store`
- QEMU image and starlte rootfs/boot image packaging
- CI image builds and the test that inspects the starlte image

Still outside the Nix build, or not validated:

- the starlte kernel/initramfs/boot image (prebuilt)
- starlte hardware boot, display, touch, Wi-Fi, modem, audio, sensors
- WPE WebKit, so the ztMETRO browser is not built
- the old preloaded app set (Music, WhatsApp, Firefox, Chromium); on NixOS,
  install/run apps through the Store app, `ztos-store`, and `ztos-run`
- the SDK/music/WhatsApp packaging, which still follows the legacy layout

The old `installer/ztos` and the Arch Linux ARM build remain in the tree for
the historical phone port. They are not used by any NixOS output.

## Troubleshooting

**The window is huge and only part of the UI is visible.** ztMETRO is drawing
at the built-in `scale = 4` because `~/.config/ztmetro/config` is missing. Set
`scale = 1.2` in that file and restart the session.

**The session starts locked.** Older images have `lock = on`; set
`lock = off` and reboot. Locking on idle is controlled by the `lock` and
`timeout` keys, not by the QEMU power button.

**The screen is black for a while on first boot.** The image is growing and
starting NixOS services. Give it a minute; use the QEMU monitor if you need
the serial console.

**`nix build .#images.qemu` fails on a Mac.** This is an `aarch64-linux`
output. Use the CI artifact or a Linux builder. `nix develop` on macOS is for
running the downloaded image, not building it.

**The artifact download stalls.** The GitHub artifact API has been unreliable
for this ~1.8 GB artifact; download it from the run page in a browser.
