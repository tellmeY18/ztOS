{
  pkgs,
  config,
  ...
}:

pkgs.callPackage (import (pkgs.path + "/nixos/lib/make-disk-image.nix")) {
  inherit config;

  name = "ztos-qemu";
  baseName = "ztos-qemu";
  partitionTableType = "efi";
  format = "qcow2";
  diskSize = "auto";
  additionalSpace = "2G";
  installBootLoader = true;
  touchEFIVars = true;
}
