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
    # The QEMU image is booted directly with -kernel/-initrd, so it needs no
    # bootloader or EFI system partition.
    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = false;
    boot.loader.efi.canTouchEfiVariables = false;

    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
      options = [
        "rw"
        "relatime"
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
