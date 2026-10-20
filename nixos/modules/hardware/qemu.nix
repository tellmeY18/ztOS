{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  cfg = config.ztos;
in
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  config = lib.mkIf (cfg.enable && cfg.hardware == "qemu") {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    fileSystems."/" = {
      device = "/dev/disk/by-partlabel/ztos-root";
      fsType = "ext4";
      options = [
        "rw"
        "relatime"
      ];
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-partlabel/ztos-esp";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    boot.initrd.availableKernelModules = [
      "9p"
      "9pnet_virtio"
      "ext4"
      "virtio_blk"
      "virtio_pci"
      "virtio_scsi"
    ];

    boot.kernelParams = [ "console=ttyAMA0" ];

    services.qemuGuest.enable = true;

    environment.systemPackages = with pkgs; [
      parted
      gptfdisk
    ];
  };
}
