# Package store

ztOS on NixOS uses declarative system package management. The Store app and
`ztos-store` add apps to `/etc/nixos/packages.nix` and rebuild the NixOS
generation. Nothing is added to a user profile, so an installed app stays
installed across updates and rollbacks.

```sh
ztos-store search firefox
sudo ztos-store install firefox
ztos-store installed
sudo ztos-store uninstall firefox
```

`ztos-store` writes `/etc/nixos/packages.nix`, which the bootstrap flake at
`/etc/nixos/flake.nix` imports. On first activation, `ztos.store.bootstrap`
writes that flake and keeps the ztOS source in
`/nix/var/nix/gcroots/ztos/source`; the QEMU and starlte configurations enable
it. The rebuild itself is `ztos-update apply`, the same command used for system
updates.

The GUI is in `../store-gui/` and is packaged as `ztos-store-gui`. It calls the
same `ztos-store` commands for search, install, and uninstall.

`pin` remains for a temporary package kept alive by a GC root, without changing
the system generation:

```sh
sudo ztos-store pin nixpkgs#firefox
ztos-store list
sudo ztos-store remove firefox
ztos-run nixpkgs#firefox -- --private-window
```

Pinned apps live under `/nix/var/nix/gcroots/ztos/apps` and their launchers in
`/var/lib/ztos/share/applications`, which ztMETRO scans alongside its built-in
directories.

The C App Store in this directory (`ztstore`) is the old pacman/AUR front end
from the Arch Linux ARM tree. It is kept for reference and for the parser tests
(`make check-store`); it is not part of the NixOS image.

## Building and checking

    make store/ztstore     # legacy pacman/AUR front end
    make check-store       # its parsers, against a made-up pacman layout
