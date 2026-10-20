{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;

  update = pkgs.runCommand "ztos-update" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    install -Dm755 ${../scripts/ztos-update} $out/bin/ztos-update
    patchShebangs $out/bin
    wrapProgram $out/bin/ztos-update \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.nix
          pkgs.git
          pkgs.coreutils
          pkgs.util-linux
          pkgs.gnused
          pkgs.gnugrep
          pkgs.jq
          config.system.build.nixos-rebuild
        ]
      }
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.update.enable) {
    environment.systemPackages = [ update ];

    environment.etc."ztos/update.conf".text = ''
      FLAKE=${cfg.update.flake}
      HOST=${cfg.update.host}
      MODE=${cfg.update.mode}
    '';

    systemd.services.ztos-update-check = {
      description = "ztOS: look for a new system generation";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${update}/bin/ztos-update check";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.ztos-update-check = {
      description = "ztOS: look for updates once a day";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "1d";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    systemd.services.ztos-update-apply = {
      description = "ztOS: build and install the new generation";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${update}/bin/ztos-update apply";
      };
    };
  };
}
