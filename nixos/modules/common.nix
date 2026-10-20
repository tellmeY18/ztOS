{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;

  overlayRoots = [
    ../../os/overlay/etc
    ../../rootfs/overlay/etc
  ];

  excluded = [
    "environment"
    "fonts/"
    "fstab"
    "greetd/"
    "hostname"
    "os-release"
    "pipewire/"
    "skel/"
    "sudoers.d/"
    "systemd/network/"
    "systemd/system/"
    "udev/"
    "wireplumber/"
    "ztstore/"
  ];

  relative = root: path: lib.removePrefix (toString root + "/") (toString path);

  wanted = path: !(lib.any (prefix: lib.hasPrefix prefix path) excluded);

  etcFiles = lib.concatMap (
    root:
    map (path: {
      name = relative root path;
      value.source = path;
    }) (lib.filter (path: wanted (relative root path)) (lib.filesystem.listFilesRecursive root))
  ) overlayRoots;

  ztosFonts = pkgs.runCommand "ztos-fonts" { } ''
    mkdir -p $out/share/fonts/truetype
    cp ${../../os/overlay/usr/local/share/fonts/segoe}/*.ttf $out/share/fonts/truetype/
  '';

  # Do not put this under environment.etc: NixOS makes /etc/fonts a symlink to
  # the fontconfig store path, so writing into it fails in the sandbox.
  fontconfigConf = pkgs.writeTextDir "etc/fonts/conf.d/45-ztos-segoe.conf" (
    builtins.readFile ../../os/overlay/etc/fonts/conf.d/45-ztos-segoe.conf
  );

  udevRules = lib.concatMap (
    root:
    let
      dir = root + "/udev";
    in
    lib.optionals (builtins.pathExists dir) (
      map builtins.readFile (lib.filesystem.listFilesRecursive dir)
    )
  ) overlayRoots;
in
{
  config = lib.mkIf cfg.enable {
    networking.hostName = lib.mkDefault "ztos";
    networking.networkmanager.enable = true;
    networking.wireless.enable = lib.mkForce false;

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    services.openssh.enable = lib.mkDefault true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
    security.rtkit.enable = true;

    hardware.bluetooth.enable = true;

    i18n.defaultLocale = "en_US.UTF-8";
    time.timeZone = lib.mkDefault "UTC";

    fonts.packages = with pkgs; [
      dejavu_fonts
      noto-fonts
      noto-fonts-color-emoji
      ztosFonts
    ];
    fonts.fontconfig.confPackages = [ fontconfigConf ];

    environment.etc = lib.listToAttrs etcFiles;

    environment.systemPackages = with pkgs; [
      alsa-utils
      curl
      git
      iw
      jq
      wget
      wireplumber
      wpa_supplicant
    ];

    services.udev.extraRules = lib.concatStringsSep "\n" (
      [ ''
        SUBSYSTEM=="backlight", TAG+="systemd"
      '' ] ++ udevRules
    );
  };
}
