{
  pkgs,
  config,
  ...
}:

let
  rootfs = pkgs.callPackage (import (pkgs.path + "/nixos/lib/make-ext4-fs.nix")) {
    storePaths = [ config.system.build.toplevel ];
    volumeLabel = "nixos";
    populateImageCommands = ''
      mkdir -p ./files/{etc,var,run,tmp,root,home,dev,proc,sys,sbin}
      chmod 1777 ./files/tmp
      ln -s ${config.system.build.toplevel}/init ./files/init
      ln -s ${config.system.build.toplevel}/init ./files/sbin/init
    '';
  };
in
pkgs.runCommand "ztos-qemu-image" { } ''
  mkdir -p $out
  cp ${rootfs} $out/rootfs.img
  cp ${config.system.build.kernel}/Image $out/Image
  cp ${config.system.build.initialRamdisk}/initrd $out/initrd
  cat > $out/README <<'EOF'
  Boot this image with the ztos-qemu helper from the devshell:

      nix develop
      ztos-qemu $PWD/result

  Or run QEMU manually with the Image, initrd and rootfs.img in this directory.
  EOF
''
