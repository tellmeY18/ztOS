{
  lib,
  ...
}:

{
  imports = [ ../modules ];

  ztos = {
    enable = true;
    hardware = "qemu";
    user = "ztos";
    password = "ztos";
    ztmetro.enable = true;
    update.enable = true;
    store.enable = true;
  };

  networking.hostName = "ztos";

  system.stateVersion = "25.11";
}
