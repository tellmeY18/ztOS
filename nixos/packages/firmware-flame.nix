{
  pkgs,
  ...
}:

# Firmware for the Pixel 4, from the Nura port's firmware-google-flame
# package: WCN3990 Wi-Fi/Bluetooth, the ADSP/CDSP/modem firmware the SM8150
# needs, and the signed zap shader the Adreno 640 needs before it will run.
# A few of these are stored compressed; the kernel config enables zstd
# firmware decompression.
pkgs.stdenvNoCC.mkDerivation {
  pname = "firmware-google-flame";
  version = "f25f967";

  src = pkgs.fetchzip {
    url = "https://gitlab.postmarketos.org/andrewgigena/firmware-google-flame/-/archive/f25f967d19a2f5cee5906bfce313ce734007a6be/firmware-google-flame-f25f967d19a2f5cee5906bfce313ce734007a6be.tar.gz";
    hash = "sha256-06SFukpya8cEuPgAIbkjoGuZ6XU1p7t2G5ACrZMqD1c=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -a lib/firmware $out/lib/firmware
    runHook postInstall
  '';

  meta = {
    description = "Firmware for the Google Pixel 4 (flame)";
    license = pkgs.lib.licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" ];
  };
}
