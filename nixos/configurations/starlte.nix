{
  ...
}:

{
  imports = [ ../modules ];

  ztos = {
    enable = true;
    hardware = "starlte";
    user = "zerone";
    password = null;
    ztmetro.enable = true;
    update.enable = true;
    store.enable = true;
  };

  networking.hostName = "ztos";

  system.stateVersion = "25.11";
}
