{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ztos;

  run = pkgs.runCommand "ztos-run" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    install -Dm755 ${../scripts/ztos-run} $out/bin/ztos-run
    patchShebangs $out/bin
    wrapProgram $out/bin/ztos-run \
      --prefix PATH : ${lib.makeBinPath [ pkgs.nix pkgs.coreutils ]}
  '';

  store = pkgs.runCommand "ztos-store" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    install -Dm755 ${../scripts/ztos-store} $out/bin/ztos-store
    patchShebangs $out/bin
    wrapProgram $out/bin/ztos-store \
      --prefix PATH : ${lib.makeBinPath [ pkgs.nix pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.jq ]}
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.store.enable) {
    environment.systemPackages = [
      run
      store
    ];

    # ztMETRO scans these in addition to its built-in directories; a pinned app
    # is just a .desktop file that calls ztos-run.
    systemd.tmpfiles.rules = [
      "d /nix/var/nix/gcroots/ztos 0755 root root -"
      "d /nix/var/nix/gcroots/ztos/apps 0755 root root -"
    ];
  };
}
