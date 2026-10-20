{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ztos-firmware";
  version = "0.1.0-alpha2";

  src = ../..;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware/brcm

    install -m644 firmware/bcmdhd_sta.bin_b2 \
      $out/lib/firmware/brcm/brcmfmac4361-pcie.bin
    install -m644 firmware/nvram.txt_r02a_b2 \
      $out/lib/firmware/brcm/brcmfmac4361-pcie.txt
    install -m644 firmware/bcmdhd_clm.blob \
      $out/lib/firmware/brcm/brcmfmac4361-pcie.clm_blob

    for f in firmware/calliope_*.bin; do
      [ -e "$f" ] && install -m644 "$f" $out/lib/firmware/
    done

    if [ -e third_party/s9plus/firmware/regulatory.db ]; then
      install -m644 third_party/s9plus/firmware/regulatory.db $out/lib/firmware/
      install -m644 third_party/s9plus/firmware/regulatory.db.p7s $out/lib/firmware/
    fi

    runHook postInstall
  '';

  meta = {
    description = "ztOS firmware for the Galaxy S9 (starlte)";
    homepage = "https://github.com/tellmeY18/ztOS";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.platforms.linux;
  };
})
