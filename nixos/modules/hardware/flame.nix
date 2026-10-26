{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;

  kernel = pkgs.callPackage ../../packages/linux-flame.nix { };
  firmware = pkgs.callPackage ../../packages/firmware-flame.nix { };
in
{
  config = lib.mkIf (cfg.enable && cfg.hardware == "flame") {
    # The kernel is the SM8150 fork the Nura (postmarketOS) Pixel 4 port uses.
    # It is the only tree with the flame display and touch drivers today; the
    # upstream kernel still has no sm8150-google-flame device tree.
    boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor kernel);

    # UFS and ext4 are built into this kernel, so ztOS boots without an
    # initramfs: the kernel mounts userdata directly. That also keeps the
    # module directory and the running kernel in step, which the Nura-style
    # U-Boot chain has no initramfs to reconcile.
    boot.initrd.enable = false;
    boot.kernelModules = lib.mkForce [ ];
    boot.extraModulePackages = lib.mkForce [ ];
    boot.initrd.availableKernelModules = lib.mkForce [ ];

    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = false;
    boot.loader.generic-extlinux-compatible.enable = false;

    # U-Boot passes these to the kernel from extlinux.conf; root is the ext4
    # filesystem ztOS writes to the userdata partition.
    boot.kernelParams = [
      "root=PARTLABEL=userdata"
      "rootfstype=ext4"
      "rootwait"
      "rw"
      "console=tty0"
      "console=ttyMSM0,115200n8"
      "panic=5"
      "keep_bootcon"
    ];

    fileSystems."/" = {
      device = "/dev/disk/by-partlabel/userdata";
      fsType = "ext4";
      options = [
        "rw"
        "noatime"
      ];
    };

    hardware.firmware = [
      firmware
      pkgs.linux-firmware
    ];

    # The archive ships some firmware as .zst already; do not recompress.
    hardware.firmwareCompression = "none";

    systemd.services.ztos-grow-root = {
      description = "Grow the ztOS root filesystem to fill userdata";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.e2fsprogs}/bin/resize2fs /dev/disk/by-partlabel/userdata";
        RemainAfterExit = true;
      };
    };
  };
}
