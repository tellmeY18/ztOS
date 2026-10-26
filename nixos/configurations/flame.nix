{
  ...
}:

{
  imports = [ ../modules ];

  ztos = {
    enable = true;
    hardware = "flame";
    user = "zerone";
    password = null;
    ztmetro.enable = true;
    update.enable = true;
    store.enable = true;
    store.bootstrap = true;
  };

  networking.hostName = "flame";

  system.stateVersion = "25.11";
}
