{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ztos-scripts";
  version = "0.1.0-alpha2";

  src = ../..;

  dontBuild = true;
  dontConfigure = true;
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/usr/local/bin $out/usr/local/sbin
    mkdir -p $out/usr/local/lib $out/usr/local/libexec
    mkdir -p $out/usr/local/share

    cp -a os/overlay/usr/local/bin/. $out/usr/local/bin/
    cp -a os/overlay/usr/local/sbin/. $out/usr/local/sbin/
    cp -a os/overlay/usr/local/lib/. $out/usr/local/lib/
    cp -a os/overlay/usr/local/libexec/. $out/usr/local/libexec/
    cp -a os/overlay/usr/local/share/. $out/usr/local/share/

    cp -a rootfs/overlay/usr/local/bin/. $out/usr/local/bin/
    cp -a rootfs/overlay/usr/local/sbin/. $out/usr/local/sbin/
    if [ -d rootfs/overlay/usr/local/lib ]; then
      cp -a rootfs/overlay/usr/local/lib/. $out/usr/local/lib/
    fi
    if [ -d rootfs/overlay/usr/local/libexec ]; then
      cp -a rootfs/overlay/usr/local/libexec/. $out/usr/local/libexec/
    fi
    if [ -d rootfs/overlay/usr/local/share ]; then
      cp -a rootfs/overlay/usr/local/share/. $out/usr/local/share/
    fi

    install -d $out/usr/local/share/fonts/selawik
    install -m644 os/fonts/selawik/*.ttf $out/usr/local/share/fonts/selawik/

    rm -f $out/usr/local/sbin/ztos-update
    rm -f $out/usr/local/sbin/ztstore-helper
    rm -rf $out/usr/local/libexec/ztstore
    rm -f $out/usr/local/sbin/zboot-pacman
    rm -f $out/usr/local/sbin/zboot-firstboot
    rm -f $out/usr/local/sbin/zboot-session
    rm -f $out/usr/local/bin/zboot-osk
    rm -f $out/usr/local/bin/gnome-session-starlte
    rm -f $out/usr/local/bin/ztmetro-session

    chmod -R u+rwX,go+rX $out
    find $out/usr/local/bin $out/usr/local/sbin $out/usr/local/libexec -type f -exec chmod 755 {} +

    runHook postInstall
  '';

  meta = {
    description = "ztOS system scripts and compatibility files";
    homepage = "https://github.com/tellmeY18/ztOS";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
})
