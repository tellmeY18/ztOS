{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;
  ztmetro = pkgs.callPackage ../packages/ztmetro.nix { };
  ztosScripts = pkgs.callPackage ../packages/ztos-scripts.nix { };
in
{
  options.ztos = {
    enable = lib.mkEnableOption "ztOS";

    user = lib.mkOption {
      type = lib.types.str;
      default = "ztos";
      description = "The account ztMETRO runs as.";
    };

    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Initial password for the ztOS user. Null leaves the account locked.";
    };

    hardware = lib.mkOption {
      type = lib.types.enum [
        "generic"
        "qemu"
        "starlte"
        "flame"
      ];
      default = "generic";
      description = "The hardware profile ztOS is built for.";
    };

    ztmetro = {
      enable = lib.mkEnableOption "the ztMETRO session";
    };

    update = {
      enable = lib.mkEnableOption "the ztOS updater";

      flake = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nixos";
        description = "The flake that describes this system.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "The nixosConfiguration attribute to rebuild.";
      };

      mode = lib.mkOption {
        type = lib.types.enum [
          "switch"
          "boot"
        ];
        default = "switch";
        description = "Whether an update switches immediately or arms the next boot.";
      };
    };

    store = {
      enable = lib.mkEnableOption "the no-profile ztOS package store";

      bootstrap = lib.mkEnableOption "a writable /etc/nixos flake for the store";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "ztos.user must not be root";
      }
    ];

    system.nixos = {
      distroName = "ztOS";
      distroId = "ztos";
      vendorName = "ztOS";
      vendorId = "ztos";
      extraOSReleaseArgs = {
        PRETTY_NAME = "ztOS 0.1.0-ALPHA-2";
        VERSION_ID = "0.1.0-ALPHA-2";
        BUILD_ID = "ALPHA-2";
        ANSI_COLOR = "38;2;0;80;239";
        LOGO = "ztos";
        HOME_URL = "https://github.com/Zerone-Laboratories/ztOS";
        DOCUMENTATION_URL = "https://github.com/Zerone-Laboratories/ztOS#readme";
        SUPPORT_URL = "https://github.com/Zerone-Laboratories/ztOS/issues";
        BUG_REPORT_URL = "https://github.com/Zerone-Laboratories/ztOS/issues";
      };
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    nixpkgs.config.allowUnfree = true;

    users.users.${cfg.user} = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "wheel"
        "video"
        "render"
        "input"
        "audio"
        "networkmanager"
      ];
      shell = pkgs.bash;
    } // lib.optionalAttrs (cfg.password != null) {
      initialPassword = cfg.password;
    };

    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/reboot";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/touch";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    hardware.graphics.enable = true;

    environment.systemPackages = [
      ztmetro
      ztosScripts
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.wl-clipboard
      pkgs.xdg-user-dirs
      pkgs.libinput
      pkgs.mesa
    ];

    environment.sessionVariables = {
      PAN_MAX_AFBC_PACKING_RATIO = "0";
      PAN_MESA_DEBUG = "noafbc";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/ztos 0755 root root -"
      "d /var/lib/ztos/apps 0755 root root -"
      "d /var/lib/ztos/share 0755 root root -"
      "d /var/lib/ztos/share/applications 0755 root root -"
      "d /var/lib/ztos/share/icons 0755 root root -"
      "d /var/lib/ztos/share/icons/hicolor 0755 root root -"
      "d /var/lib/ztos/share/icons/hicolor/scalable 0755 root root -"
      "d /var/lib/ztos/share/icons/hicolor/scalable/apps 0755 root root -"
      "d /var/lib/ztos-pstore 0755 root root -"
    ];

    system.activationScripts.ztos-compat = {
      text = ''
        mkdir -p /usr/local
        for dir in bin sbin lib libexec share; do
          rm -rf "/usr/local/$dir"
          if [ -d "${ztosScripts}/usr/local/$dir" ]; then
            ln -s "${ztosScripts}/usr/local/$dir" "/usr/local/$dir"
          fi
        done

        mkdir -p /usr/bin
        ln -sfn ${config.systemd.package}/bin/systemctl /usr/bin/systemctl
        ln -sfn ${config.systemd.package}/bin/reboot /usr/bin/reboot
        ln -sfn ${pkgs.coreutils}/bin/chgrp /usr/bin/chgrp
        ln -sfn ${pkgs.coreutils}/bin/chmod /usr/bin/chmod
        ln -sfn ${pkgs.coreutils}/bin/chroot /usr/bin/chroot
        ln -sfn ${pkgs.coreutils}/bin/env /usr/bin/env
        ln -sfn ${pkgs.coreutils}/bin/touch /usr/bin/touch
        ln -sfn ${pkgs.python3}/bin/python3 /usr/bin/python3
        ln -sfn ${pkgs.procps}/bin/pkill /usr/bin/pkill
        ln -sfn ${pkgs.util-linux}/bin/setsid /usr/bin/setsid
      '';
    };
  };
}
