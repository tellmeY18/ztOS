{
  pkgs,
  config,
  ...
}:

let
  version = pkgs.lib.removeSuffix "\n" (builtins.readFile ../../VERSION);

  rootfs = pkgs.callPackage (import (pkgs.path + "/nixos/lib/make-ext4-fs.nix")) {
    storePaths = [ config.system.build.toplevel ];
    volumeLabel = "ZR_ARCH";
    populateImageCommands = ''
      mkdir -p ./files/etc
      mkdir -p ./files/var/lib/nixos
      mkdir -p ./files/var/lib/ztos
      mkdir -p ./files/var/log
      mkdir -p ./files/nix/var/nix/db
      mkdir -p ./files/run
      mkdir -p ./files/tmp
      mkdir -p ./files/root
      mkdir -p ./files/home
      mkdir -p ./files/dev
      mkdir -p ./files/proc
      mkdir -p ./files/sys
      mkdir -p ./files/sbin
      mkdir -p ./files/lib/modules/7.1.0-zboot/extra

      chmod 1777 ./files/tmp
      chmod 0755 ./files/root

      ln -s ${config.system.build.toplevel}/init ./files/sbin/init

      cp -a ${config.hardware.firmware}/lib/firmware ./files/lib/
      cp -a ${../../prebuilts/modules}/. ./files/lib/modules/7.1.0-zboot/extra/
      ${pkgs.kmod}/bin/depmod -b ./files 7.1.0-zboot
    '';
  };

  bootImage = ../../prebuilts/boot/ztos-starlte-boot.img;
in
pkgs.runCommand "ztos-starlte-${version}" {
  nativeBuildInputs = [
    pkgs.coreutils
  ];
} ''
  mkdir -p $out
  cp ${rootfs} $out/rootfs.img
  cp ${bootImage} $out/boot.img

  cat > $out/flash.sh <<'EOF'
  #!/bin/sh
  set -eu
  HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  ADB=''${ADB:-adb}
  BOOT_PART=''${BOOT_PART:-/dev/block/by-name/BOOT}
  ROOT_PART=''${ROOT_PART:-/dev/block/by-name/USERDATA}

  if ! "$ADB" get-state >/dev/null 2>&1; then
    echo "connect the phone in TWRP with adb" >&2
    exit 1
  fi

  echo "This overwrites BOOT and USERDATA. Type ERASE to continue."
  read -r answer
  [ "$answer" = ERASE ] || exit 1

  "$ADB" push "$HERE/boot.img" /tmp/ztos-boot.img
  "$ADB" shell "dd if=/tmp/ztos-boot.img of=$BOOT_PART bs=1M conv=fsync"
  "$ADB" push "$HERE/rootfs.img" /tmp/ztos-rootfs.img
  "$ADB" shell "dd if=/tmp/ztos-rootfs.img of=$ROOT_PART bs=1M conv=fsync"
  "$ADB" shell sync
  echo "flashed; reboot the phone"
  EOF
  chmod 0755 $out/flash.sh

  cat > $out/build.json <<EOF
  {
    "codename": "starlte",
    "version": "${version}",
    "boot": "prebuilts/boot/ztos-starlte-boot.img",
    "boot_sha256": "$(sha256sum $out/boot.img | cut -d' ' -f1)",
    "rootfs_sha256": "$(sha256sum $out/rootfs.img | cut -d' ' -f1)",
    "rootfs_label": "ZR_ARCH",
    "kernel": "7.1.0-zboot"
  }
  EOF
''
