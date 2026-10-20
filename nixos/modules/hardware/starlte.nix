{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;

  firmware = pkgs.callPackage ../../packages/ztos-firmware.nix { };

  unitDir = ../../../rootfs/overlay/etc/systemd/system;

  excludedUnits = [
    "zboot-firstboot.service"
    "ztos-update-apply.service"
    "ztos-update-check.service"
    "ztos-update-check.timer"
    "ztstore-admin@.service"
    "ztstore-install@.service"
  ];

  unitNames = lib.filter (
    name:
    (lib.hasSuffix ".service" name || lib.hasSuffix ".timer" name)
    && !(lib.elem name excludedUnits)
  ) (builtins.attrNames (builtins.readDir unitDir));

  wantedByFor =
    name:
    if name == "zboot-charge-hold.service" || name == "ztos-pstore-keep.service" then
      [ "sysinit.target" ]
    else if lib.hasSuffix ".timer" name then
      [ "timers.target" ]
    else if
      lib.elem name [
        "zrn-cpuidle.service"
        "ztos-panel-bl.service"
        "ztos-panel-selfmask.service"
        "ztoscirrusaudio.service"
        "ztoscsf-sensorhub.service"
      ]
    then
      [ "graphical.target" ]
    else
      [ "multi-user.target" ];

  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.procps
    pkgs.psmisc
    pkgs.python3
    pkgs.shadow
    pkgs.systemd
    pkgs.util-linux
  ];

  mkUnit =
    name:
    let
      text = builtins.readFile (unitDir + "/${name}");
    in
    {
      text =
        lib.replaceStrings
          [
            "/usr/bin/chroot"
            "/usr/bin/touch"
          ]
          [
            "${pkgs.coreutils}/bin/chroot"
            "${pkgs.coreutils}/bin/touch"
          ]
          text
        + lib.optionalString (lib.hasSuffix ".service" name) ''

          [Service]
          Environment=PATH=${servicePath}
        '';
      wantedBy = wantedByFor name;
    };
in
{
  config = lib.mkIf (cfg.enable && cfg.hardware == "starlte") {
    # The real ztOS kernel is built by scripts/build-boot.sh and packed by
    # uniLoader. Until that derivation is wired in, this is the closest
    # nixpkgs kernel and only keeps the closure evaluable; it is not bootable
    # on starlte.
    #
    # Do not enable boot.supportedFilesystems = [ "zfs" ] here: the ZFS module
    # pins boot.kernelPackages to linuxPackages, which would silently replace
    # the kernel ztOS needs. If ZFS is ever wanted, override that pin first.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # The phone boots the kernel from prebuilts/boot/ztos-starlte-boot.img,
    # not a NixOS stage-1 initrd. Its modules live in /lib/modules/7.1.0-zboot.
    boot.initrd.enable = false;
    boot.kernelModules = lib.mkForce [ ];
    boot.extraModulePackages = lib.mkForce [ ];
    boot.initrd.availableKernelModules = lib.mkForce [ ];

    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = false;
    boot.loader.generic-extlinux-compatible.enable = false;

    boot.kernelParams = [
      "console=tty0"
      "panic=5"
      "keep_bootcon"
    ];

    fileSystems."/" = {
      device = "/dev/disk/by-label/ZR_ARCH";
      fsType = "ext4";
      options = [
        "rw"
        "noatime"
      ];
    };

    hardware.firmware = [ firmware ];
    hardware.firmwareCompression = "none";

    services.pipewire.configPackages = [
      (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/10-s9-quantum.conf" (
        builtins.readFile ../../../rootfs/overlay/etc/pipewire/pipewire.conf.d/10-s9-quantum.conf
      ))
    ];

    services.pipewire.wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-s9-abox-buffer.conf" (
        builtins.readFile ../../../rootfs/overlay/etc/wireplumber/wireplumber.conf.d/51-s9-abox-buffer.conf
      ))
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/52-ztos-bluetooth.conf" (
        builtins.readFile ../../../rootfs/overlay/etc/wireplumber/wireplumber.conf.d/52-ztos-bluetooth.conf
      ))
    ];

    systemd.units = lib.listToAttrs (
      map (name: {
        inherit name;
        value = mkUnit name;
      }) unitNames
    );

    systemd.services.ztos-grow-root = {
      description = "Grow the ztOS root filesystem to fill USERDATA";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.e2fsprogs}/bin/resize2fs /dev/disk/by-label/ZR_ARCH";
        RemainAfterExit = true;
      };
    };
  };
}
