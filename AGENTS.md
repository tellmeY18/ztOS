# AGENTS.md

## What this repository is

ztOS is a phone operating system built on **NixOS**, with the ztMETRO shell
(Windows Phone 8.1's look and motion) on top of wlroots. The flake builds the
complete system: userspace, ztMETRO, services, updater, package store, and the
QEMU and Samsung Galaxy S9 (`starlte`) images.

**NixOS is the only supported target.** The `os/`, `rootfs/`, `installer/`,
`initramfs/`, `kernel/`, and most of the top-level `scripts/` directories are
the old Arch Linux ARM flow kept for reference. Do not add new features or
documentation to that flow. New work belongs in `nixos/`, `ztmetro/`, or the
hardware directories that are still consumed by the NixOS image.

## Repository map

| Path | What it is |
|---|---|
| `flake.nix` | flake outputs: `nixosConfigurations`, `images`, `packages`, `devShells` |
| `nixos/` | the NixOS port: modules, configurations, image builders, scripts, packages |
| `nixos/modules/` | `ztos`, `common`, `session`, `update`, `store`, and hardware profiles |
| `nixos/configurations/` | `qemu.nix` and `starlte.nix` |
| `nixos/images/` | `images.qemu` and `images.starlte` bundles |
| `nixos/packages/` | `ztmetro`, `ztos-store-gui`, `ztos-scripts`, `ztos-firmware` derivations |
| `nixos/scripts/` | `run-qemu`, `ztos-run`, `ztos-store`, `ztos-update` |
| `ztmetro/` | the compositor, the ZrnMetroCore toolkit, bundled apps, daemons |
| `sdk/` | third-party Python/Qt SDK and app templates |
| `audio/`, `modem/`, `sensors/`, `power/`, `leds/`, `haptics/`, `firmware/`, `camera/`, `bluetooth/`, `media/` | phone hardware support (kernel modules, firmware, daemons) |
| `prebuilts/` | prebuilt starlte kernel/initramfs/boot image and modules |
| `docs/` | the static website and screenshots |

Legacy Arch-only paths: `os/`, `rootfs/`, `installer/`, `initramfs/`,
`kernel/`, `scripts/build-arch-root.sh`, `scripts/build-boot.sh`,
`scripts/pacman-proxy.py`, and the `zboot-*` helpers.

## Development commands

Use the devshell for QEMU and image tooling:

```sh
nix develop
```

Run a downloaded or locally built QEMU bundle:

```sh
ztos-qemu /path/to/bundle
# or, from the repository:
nix develop --command ztos-qemu "$PWD/result"
```

The helper defaults to a 540x1110 phone-shaped display (ztMETRO at
`scale = 1.2`). Override with `ZTOS_QEMU_WIDTH` / `ZTOS_QEMU_HEIGHT`, and use
`ZTOS_QEMU_DISPLAY=vnc=:1` for VNC.

Build images (requires `aarch64-linux`; cannot be built natively on
`aarch64-darwin`):

```sh
nix build .#images.qemu -L
nix build .#images.starlte -L
sh nixos/tests/image.sh ./result
```

Build and test the shell on Linux:

```sh
make -C ztmetro
make -C ztmetro check-store
```

Run the flake checks:

```sh
nix flake check
```

## QEMU image notes

- The QEMU image is a direct-kernel boot: `Image`, `initrd`, `rootfs.img`,
  and optionally `cmdline`.
- The guest login is `ztos` / `ztos`; the graphical session starts through
  `greetd`.
- `ztos-qemu` grows the raw image and ext4 filesystem by 8 GiB when less than
  2 GiB is free. `ZTOS_QEMU_GROW=0` disables it; `ZTOS_QEMU_GROW=16G` changes
  the amount. The guest also runs `resize2fs` at boot.
- On macOS the default display is `cocoa,show-cursor=on`; set
  `ZTOS_QEMU_DISPLAY` to override it (`vnc=:1` for VNC).
- `~/.config/ztmetro/config` inside the image controls `scale`, `lock`, and
  `timeout`. The QEMU configuration writes `scale = 1.2`, `lock = off`,
  `timeout = 0` on first boot when the file is absent.
- `scale` is the wlroots output scale. At 540x1110 and `scale = 1.2` the
  logical area is 450x925 points. Increase resolution to make the window
  larger; change `scale` to change UI size.
- The running VM's display can be inspected with the QEMU monitor
  `screendump` command. On macOS, convert the resulting PPM with `sips`.
- The rootfs can be inspected or repaired offline with `debugfs`/`e2fsck` from
  the devshell; do not mount ext4 on macOS.

## Conventions

- Keep documentation **NixOS-first**. Do not present Arch Linux ARM, `pacman`,
  or the old installer as a supported path. When touching legacy files, label
  them as legacy rather than extending them.
- Follow the existing C style in `ztmetro/`; do not add comments unless they
  explain non-obvious hardware or protocol behaviour.
- Prefer `nix` outputs over hand-built artifacts. Do not commit `result`,
  `build/`, `out/`, or image files.
- Keep `flake.nix` outputs working for `aarch64-linux`; the devshell also
  supports `aarch64-darwin` for running images.
- Licensing: userspace and apps are GPL-3.0-or-later; kernel drivers and device
  trees are GPL-2.0-only.

## Further reading

- `README.md`: user-facing overview and quick start.
- `nixos/README.md`: NixOS port details, outputs, and troubleshooting.
- `.opencode/skills/ztos-nixos/SKILL.md`: repeatable QEMU, image, and docs
  workflows.
