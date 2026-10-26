{
  pkgs,
  ...
}:

# U-Boot as the Pixel 4's secondary bootloader. The stock ABL in boot_a cannot
# load a mainline kernel, so U-Boot goes there and boots the kernel itself, the
# same chain the Nura (postmarketOS) port uses:
#
#   ABL -> U-Boot (boot_a) -> extlinux.conf on userdata -> Image + dtb
#
# The only change to the upstream board env is bootcmd: instead of the EFI
# boot manager on a FAT ESP, scan the UFS partitions for extlinux.conf, which
# lets ztOS keep its kernel and dtb inside the ext4 root filesystem.
pkgs.stdenv.mkDerivation {
  pname = "u-boot-flame";
  version = "2025.04";

  src = pkgs.fetchzip {
    url = "https://gitlab.com/andrewgigena/u-boot/-/archive/andrew%2Fgoogle-flame/u-boot-andrew-google-flame.tar.gz";
    hash = "sha256-ifC2Zsfb+V3TrVtnlzIv7Lbqvy1aFA6deRQMIwSX9U4=";
  };

  nativeBuildInputs = with pkgs; [
    bc
    bison
    dtc
    flex
    gnutls
    libuuid
    openssl
    pkg-config
    python3
    python3Packages.setuptools
    swig
    xxd
  ];

  hardeningDisable = [ "all" ];

  postPatch = ''
    # Boot the kernel from the ext4 root filesystem instead of an EFI boot
    # manager on a FAT ESP: find /boot/extlinux/extlinux.conf on the UFS
    # partitions and let bootstd load Image and the dtb from there.
    substituteInPlace board/qualcomm/qcom-phone.env \
      --replace-fail \
        'bootcmd=bootefi bootmgr; pause; run menucmd' \
        'bootcmd=scsi scan; bootflow scan -b; pause; run menucmd'
  ''
  + ''
    # The qcom boards define no load addresses of their own; bootstd and
    # booti need them. These match dragonboard820c's layout and sit below
    # where U-Boot relocates itself in the 6 GiB of DRAM.
    cat >> board/qualcomm/qcom-phone.env <<'EOF'
    kernel_addr_r=0x95000000
    fdt_addr_r=0x93000000
    ramdisk_addr_r=0x91000000
    scriptaddr=0x90000000
    pxefile_addr_r=0x90100000
    fdt_high=0xffffffffffffffff
    initrd_high=0xffffffffffffffff
    EOF
  '';

  configurePhase = ''
    runHook preConfigure
    make qcom_defconfig
    scripts/kconfig/merge_config.sh -m -O . .config \
      board/qualcomm/qcom-phone.config \
      board/qualcomm/sm8150-google-flame.config
    make olddefconfig
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    make -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    # The ABL expects a gzip-compressed U-Boot with the device tree appended
    # after it, packed into an Android boot image by nixos/images/flame.nix.
    gzip -9 -c u-boot-nodtb.bin > $out/u-boot-nodtb.bin.gz
    cp u-boot.dtb $out/
    cp .config $out/config
    runHook postInstall
  '';

  meta = {
    description = "U-Boot for the Google Pixel 4 (flame)";
    license = pkgs.lib.licenses.gpl2Plus;
    platforms = [ "aarch64-linux" ];
  };
}
