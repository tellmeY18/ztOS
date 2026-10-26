{
  pkgs,
  config,
  ...
}:

let
  lib = pkgs.lib;
  version = lib.removeSuffix "\n" (builtins.readFile ../../VERSION);

  kernel = config.boot.kernelPackages.kernel;
  uboot = pkgs.callPackage ../packages/uboot-flame.nix { };

  dtb = "${kernel}/dtbs/qcom/sm8150-google-flame.dtb";

  cmdline = lib.concatStringsSep " " config.boot.kernelParams;

  # The root filesystem goes into the userdata partition, as in the Nura port.
  # Kernel and dtb live in /boot so U-Boot can find them through extlinux,
  # which means no FAT ESP and nothing written to super.
  rootfs = pkgs.callPackage (import (pkgs.path + "/nixos/lib/make-ext4-fs.nix")) {
    storePaths = [ config.system.build.toplevel ];
    volumeLabel = "ZTOS_FLAME";
    populateImageCommands = ''
      mkdir -p ./files/etc
      mkdir -p ./files/var/lib/nixos
      mkdir -p ./files/var/lib/ztos
      mkdir -p ./files/var/log
      mkdir -p ./files/nix/var/nix/db
      mkdir -p ./files/nix/var/nix/profiles
      mkdir -p ./files/nix/var/nix/gcroots
      mkdir -p ./files/run
      mkdir -p ./files/tmp
      mkdir -p ./files/root
      mkdir -p ./files/home
      mkdir -p ./files/dev
      mkdir -p ./files/proc
      mkdir -p ./files/sys
      mkdir -p ./files/sbin
      mkdir -p ./files/lib
      mkdir -p ./files/boot/extlinux

      chmod 1777 ./files/tmp
      chmod 0755 ./files/root

      ln -s ${config.system.build.toplevel}/init ./files/sbin/init

      # Firmware has to be on the real root: the Adreno 640 will not probe
      # without its zap shader, and there is no initramfs to carry it.
      cp -a ${config.hardware.firmware}/lib/firmware ./files/lib/

      cp ${kernel}/Image ./files/boot/Image
      cp ${dtb} ./files/boot/sm8150-google-flame.dtb

      {
        echo "DEFAULT ztos"
        echo "LABEL ztos"
        echo "  LINUX /boot/Image"
        echo "  FDT /boot/sm8150-google-flame.dtb"
        echo "  APPEND ${cmdline}"
      } > ./files/boot/extlinux/extlinux.conf
    '';
  };

  # ABL accepts an Android boot image, but not a mainline kernel: this one
  # carries U-Boot. Its device tree is appended to the gzipped binary, the
  # layout the Nura port uses.
  bootImage = pkgs.runCommand "u-boot-flame.img" {
    nativeBuildInputs = [ pkgs.android-tools ];
  } ''
    cat ${uboot}/u-boot-nodtb.bin.gz ${dtb} > uboot-dtb
    mkbootimg --base 0 --kernel_offset 0x8000 --pagesize 4096 \
      --kernel uboot-dtb -o $out
  '';
in
pkgs.runCommand "ztos-flame-${version}" {
  nativeBuildInputs = [
    pkgs.coreutils
  ];
} ''
  mkdir -p $out
  cp ${bootImage} $out/uboot.img
  cp ${rootfs} $out/rootfs.img

  cat > $out/flash.sh <<'EOF'
  #!/bin/sh
  # Flash ztOS to a Google Pixel 4 (flame) that is in fastboot mode.
  #
  # This replaces the bootloader in boot_a with U-Boot, which then boots the
  # kernel and dtb kept inside the ext4 filesystem written to userdata.
  set -eu
  HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  FASTBOOT=''${FASTBOOT:-fastboot}

  if ! "$FASTBOOT" devices 2>/dev/null | grep -q .; then
    echo "put the phone in fastboot mode (power + volume down)" >&2
    exit 1
  fi

  PRODUCT=$("$FASTBOOT" getvar product 2>&1 | sed -n 's/^product: *//p' | head -n 1)
  if [ "$PRODUCT" != flame ]; then
    echo "this is '$PRODUCT', not a Pixel 4 (flame); nothing written" >&2
    exit 1
  fi

  echo "This overwrites boot_a and ERASES userdata: Android and everything"
  echo "in its storage are replaced. Type ERASE to continue."
  read -r answer
  [ "$answer" = ERASE ] || exit 1

  "$FASTBOOT" --set-active=a
  "$FASTBOOT" flash boot_a "$HERE/uboot.img"
  "$FASTBOOT" flash userdata "$HERE/rootfs.img"
  "$FASTBOOT" reboot
  echo "flashed; ztOS boots from userdata through U-Boot"
  EOF
  chmod 0755 $out/flash.sh

  cat > $out/build.json <<EOF
  {
    "codename": "flame",
    "version": "${version}",
    "uboot": "nixos/packages/uboot-flame.nix",
    "uboot_sha256": "$(sha256sum $out/uboot.img | cut -d' ' -f1)",
    "rootfs_sha256": "$(sha256sum $out/rootfs.img | cut -d' ' -f1)",
    "rootfs_label": "ZTOS_FLAME",
    "kernel": "7.0.0-sm8150",
    "kernel_params": "${cmdline}"
  }
  EOF

  cat > $out/README <<'EOF'
  Flash this bundle from a computer with fastboot:

      sh flash.sh

  The phone has to be in fastboot mode (power + volume down) and its
  bootloader unlocked. boot_a is replaced with U-Boot and userdata is
  overwritten with the ztOS root filesystem; every other partition is left
  alone, so a stock Pixel 4 factory image can put Android back.
  EOF
''
