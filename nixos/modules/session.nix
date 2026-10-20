{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;
  ztmetro = pkgs.callPackage ../packages/ztmetro.nix { };
in
{
  config = lib.mkIf (cfg.enable && cfg.ztmetro.enable) {
    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        initial_session = {
          command = "${ztmetro}/bin/ztmetro-session";
          user = cfg.user;
        };
        default_session = {
          command = "${ztmetro}/bin/ztmetro-session";
          user = cfg.user;
        };
      };
    };

    security.polkit.enable = true;

    # ztMETRO is a wlroots compositor and needs the DRM render nodes.
    users.users.${cfg.user}.extraGroups = [
      "video"
      "render"
      "input"
    ];

    environment.sessionVariables = {
      XDG_CURRENT_DESKTOP = "ztMETRO";
      XDG_SESSION_DESKTOP = "ztmetro";
      XDG_SESSION_TYPE = "wayland";
    };
  };
}
