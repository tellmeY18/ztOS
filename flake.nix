{
  description = "ztOS: the ztMETRO shell on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      mkZtos =
        system: configuration:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ configuration ];
        };
    in
    {
      packages = forAllSystems (pkgs: {
        ztmetro = pkgs.callPackage ./nixos/packages/ztmetro.nix { };
        ztos-scripts = pkgs.callPackage ./nixos/packages/ztos-scripts.nix { };
        ztos-firmware = pkgs.callPackage ./nixos/packages/ztos-firmware.nix { };
        default = pkgs.callPackage ./nixos/packages/ztmetro.nix { };
      } // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-linux") {
        linux-flame = pkgs.callPackage ./nixos/packages/linux-flame.nix { };
        uboot-flame = pkgs.callPackage ./nixos/packages/uboot-flame.nix { };
      });

      overlays.default = final: prev: {
        ztmetro = final.callPackage ./nixos/packages/ztmetro.nix { };
        ztos-scripts = final.callPackage ./nixos/packages/ztos-scripts.nix { };
        ztos-firmware = final.callPackage ./nixos/packages/ztos-firmware.nix { };
      };

      nixosModules = {
        default = import ./nixos/modules;
        ztos = import ./nixos/modules/ztos.nix;
        common = import ./nixos/modules/common.nix;
        session = import ./nixos/modules/session.nix;
        update = import ./nixos/modules/update.nix;
        store = import ./nixos/modules/store.nix;
        starlte = import ./nixos/modules/hardware/starlte.nix;
        flame = import ./nixos/modules/hardware/flame.nix;
        qemu = import ./nixos/modules/hardware/qemu.nix;
      };

      nixosConfigurations = {
        ztos-qemu = mkZtos "aarch64-linux" ./nixos/configurations/qemu.nix;
        ztos-starlte = mkZtos "aarch64-linux" ./nixos/configurations/starlte.nix;
        ztos-flame = mkZtos "aarch64-linux" ./nixos/configurations/flame.nix;
      };

      images.starlte = import ./nixos/images/starlte.nix {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        config = self.nixosConfigurations.ztos-starlte.config;
      };

      images.flame = import ./nixos/images/flame.nix {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        config = self.nixosConfigurations.ztos-flame.config;
      };

      images.qemu = import ./nixos/images/qemu.nix {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        config = self.nixosConfigurations.ztos-qemu.config;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bashInteractive
            pkg-config
            zlib

            # Run the QEMU image without touching the host's package manager.
            qemu
            e2fsprogs
            dosfstools
            mtools
            gptfdisk
            cpio
            xz
            zstd

            # Flash and inspect Android devices: adb/fastboot, AVB signing,
            # boot image packing, and vendor image unpacking.
            android-tools
            heimdall
            mkbootimg-osm0sis
            android-ota-payload-extractor
            payload-dumper-go
            simg2img
            dtc
            unzip
            openssl
            libusb1
            usbutils
            python3

            (pkgs.writeShellApplication {
              name = "ztos-qemu";
              runtimeInputs = [
                pkgs.qemu
                pkgs.coreutils
                pkgs.e2fsprogs
                pkgs.gawk
              ];
              text = builtins.readFile ./nixos/scripts/run-qemu;
            })
          ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
            # AVB signing: avbroot needs futility from vboot_reference, which
            # does not build on Darwin.
            avbroot

            # Build-side and desktop dependencies for the native Linux shell.
            wayland-scanner
            wlroots_0_20
            wayland
            wayland-protocols
            libxkbcommon
            cairo
            pango
            librsvg
            gdk-pixbuf
            pixman
            libdrm
            libGL
            libpulseaudio
            polkit
            systemd
            qemu-utils
            parted
            util-linux
          ]);
        };
      });
    };
}
