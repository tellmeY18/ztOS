# Installing ztOS

This directory contains the old Arch Linux ARM installer. It is **legacy** and
is not used by the NixOS build. The supported install path is the flake.

## QEMU

Download the latest `ztos-qemu-image` artifact from a successful **ztOS QEMU
image** CI run, unzip it, and run it from the devshell:

```sh
unzip ztos-qemu-image.zip -d ztos-qemu
chmod u+w ztos-qemu/rootfs.img
nix develop
ztos-qemu "$PWD/ztos-qemu"
```

Login is `ztos` / `ztos`. The default window is 540x1110 at `scale = 1.2`.

To build the image yourself on an `aarch64-linux` machine:

```sh
nix build .#images.qemu -L
nix develop
ztos-qemu ./result
```

## Galaxy S9 (starlte)

```sh
nix build .#images.starlte -L
./result/flash.sh
```

The phone must already have its bootloader unlocked and TWRP installed in
RECOVERY. `flash.sh` writes BOOT and USERDATA, refuses to continue unless you
type `ERASE`, and never touches the EFS partitions. Keep the stock Android
partitions; the modem and sensor hub need them.

If the phone does not start, it falls back to TWRP. See
[`nixos/README.md`](../nixos/README.md) for build details and
[`README.md`](../README.md) for the hardware status.

## The old installer

`installer/ztos` builds Arch Linux ARM with `pacman` in a user namespace. It is
kept for history and is not a supported ztOS install path.
