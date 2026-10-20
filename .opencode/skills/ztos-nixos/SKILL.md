---
name: ztos-nixos
description: Use when working on the ztOS NixOS port, flake outputs, QEMU image, starlte image, ztMETRO packaging, devshell, or migrating ztOS docs from Arch Linux to NixOS. Covers running and inspecting the QEMU image, guest config and display scaling, image builds, and documentation conventions.
---

# ztOS on NixOS

ztOS is a NixOS system with the ztMETRO wlroots shell. `nixos/` is the
canonical platform; the old Arch Linux ARM tree is legacy and must not be
extended.

## Run the QEMU image

Use the devshell, which provides QEMU and image tools:

```sh
cd /path/to/ztOS
nix develop --command ztos-qemu /path/to/bundle
```

The bundle directory contains `Image`, `initrd`, `rootfs.img`, and optionally
`cmdline`. A downloaded CI artifact is unpacked into such a directory.

Defaults: 540x1110 physical pixels, 4 GB RAM, HVF on macOS, KVM when writable
on Linux, TCG otherwise. Override the display with:

```sh
ZTOS_QEMU_WIDTH=540 ZTOS_QEMU_HEIGHT=1110 \
  nix develop --command ztos-qemu /path/to/bundle
```

Use `ZTOS_QEMU_DISPLAY=vnc=:1` for VNC on `localhost:5901`.

## Inspect and control a running VM

Launch QEMU with a monitor socket when screenshots or clean shutdown are
needed:

```sh
-monitor unix:/tmp/ztos-mon,server,nowait -serial none
```

Take a screenshot and convert it on macOS:

```sh
printf 'screendump /tmp/shot.ppm\n' | nc -U /tmp/ztos-mon
sips -s format png /tmp/shot.ppm --out /tmp/shot.png
```

Other monitor commands: `info status`, `system_powerdown`, `quit`.

The guest login is `ztos` / `ztos`. The graphical session starts through
`greetd`; the log is `~/.local/state/ztmetro.log` in the guest.

## Display sizing

`~/.config/ztmetro/config` controls the shell:

```ini
scale = 1.2
lock = off
timeout = 0
```

- `scale` is the wlroots output scale. The UI is designed for 360x740 logical
  points. At 432x888 and `scale = 1.2` that is 360x740; at 540x1110 it is
  450x925 (a larger window with the same UI scale).
- `timeout` is seconds without input before the screen sleeps; `0` keeps it on.
- `lock = off` disables locking after idle.
- The QEMU NixOS configuration writes this file on first boot only when it is
  missing. Existing images keep their file.

If the UI is huge, the guest is using the built-in `scale = 4` because the
config is missing. Fix the config; do not change the shell default.

## Repair a guest image offline (macOS)

`aarch64-darwin` cannot mount ext4 or build the Linux image. Use `debugfs` and
`e2fsck` from the devshell:

```sh
nix develop -c e2fsck -fy rootfs.img

printf 'scale = 1.2\nlock = off\ntimeout = 0\n' > /tmp/ztmetro-config
debugfs -w -R 'mkdir /home/ztos/.config' rootfs.img
debugfs -w -R 'mkdir /home/ztos/.config/ztmetro' rootfs.img
debugfs -w -R 'write /tmp/ztmetro-config /home/ztos/.config/ztmetro/config' rootfs.img
debugfs -w -R 'sif /home/ztos/.config/ztmetro/config uid 1000' rootfs.img
debugfs -w -R 'sif /home/ztos/.config/ztmetro/config gid 100' rootfs.img
```

Verify ownership and contents with `debugfs -R 'stat ...'` and
`debugfs -R 'cat ...'`.

A directory entry can become cross-linked to another inode after an unclean
shutdown. `e2fsck` reports it. Check with `debugfs -R 'ncheck INODE'`; remove
the bogus entry before recreating the directory, then run `e2fsck -fy` again.

## Build outputs

```sh
nix build .#images.qemu -L     # aarch64-linux only
nix build .#images.starlte -L  # aarch64-linux only
sh nixos/tests/image.sh ./result
nix flake check
```

On `aarch64-darwin`, use the CI-built `ztos-qemu-image` artifact; do not try to
build the Linux image locally.

The starlte image still relies on prebuilts (kernel, initramfs, boot image,
modules) and expects the root filesystem label `ZR_ARCH`. Keep those
constraints when changing `nixos/images/starlte.nix` or the hardware profile.

## Documentation migration rules

- Present NixOS as the only supported platform.
- Replace `pacman`, `makepkg`, `alarm` user, `zboot-*`, and Arch installer
  instructions with `nix`, `nixos-rebuild`, the `ztos` user, and the flake
  outputs.
- Keep the legacy Arch tree mentioned only as legacy, never as a quick start.
- QEMU quick start: download the CI artifact, `nix develop`,
  `ztos-qemu /path/to/bundle`.
- Phone quick start: `nix build .#images.starlte`, then `result/flash.sh` from
  TWRP.
- Update `README.md`, `nixos/README.md`, `docs/index.html`, and sub-READMEs
  together so there is one story.

## Verification checklist

- `nix flake show` or `nix flake check` parses the flake.
- The QEMU helper starts and the screenshot shows ztMETRO at the expected
  logical size.
- `~/.local/state/ztmetro.log` reports `output Virtual-1: ... at scale 1.2`.
- No current-tense Arch references remain in user-facing docs:
  `rg -n 'Arch Linux|pacman|makepkg|alarm' README.md nixos docs sdk ztmetro`.
