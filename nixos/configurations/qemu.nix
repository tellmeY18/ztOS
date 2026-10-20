{
  config,
  lib,
  ...
}:

let
  user = config.ztos.user;
  home = config.users.users.${user}.home;
  group = config.users.users.${user}.group;
in
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
    store.bootstrap = true;
  };

  networking.hostName = "ztos";

  system.stateVersion = "25.11";

  # The 432x888 QEMU output is 1.2x the 360x740 logical size ztMETRO was
  # designed for. Keep the first-boot config phone-shaped, and do not lock a
  # VM that has no real power button.
  system.activationScripts.ztmetro-qemu-config = ''
    install -d -m 0755 -o ${user} -g ${group} ${home}/.config/ztmetro
    if [ ! -e ${home}/.config/ztmetro/config ]; then
      printf 'scale = 1.2\nlock = off\ntimeout = 0\n' > ${home}/.config/ztmetro/config
      chown ${user}:${group} ${home}/.config/ztmetro/config
    fi
  '';
}
