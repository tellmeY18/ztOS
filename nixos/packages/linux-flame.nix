{
  pkgs,
  ...
}:

let
  version = "7.0.0";

  # The SM8150 kernel fork the Nura (postmarketOS) device-google-flame port
  # uses. It carries the Pixel 4 display (LG LH568WF3-ED01 with the NT37280
  # controller), touch and battery drivers that are not upstream yet. The
  # configuration is the fork's own, unmodified.
  src = pkgs.fetchzip {
    url = "https://gitlab.postmarketos.org/soc/qualcomm-sm8150/linux/-/archive/v${version}-sm8150/linux-v${version}-sm8150.tar.gz";
    hash = "sha256-gAhDX8VQprT17TzucVs9jPqkKYjvCympOKIKEt00v1o=";
  };
in
pkgs.linuxKernel.manualConfig {
  inherit version src;

  pname = "linux-flame";

  # config-sm8150.aarch64 sets CONFIG_LOCALVERSION="-sm8150", and the kernel
  # is built outside a git tree, so this is also the module directory name.
  modDirVersion = "${version}-sm8150";

  configfile = ./flame/config-sm8150.aarch64;
}
