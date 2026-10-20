{
  lib,
  stdenv,
  pkg-config,
  wayland-scanner,
  wlroots_0_20,
  wayland,
  wayland-protocols,
  libxkbcommon,
  cairo,
  pango,
  librsvg,
  gdk-pixbuf,
  pixman,
  libdrm,
  libGL,
  libpulseaudio,
  polkit,
  systemd,
  glib,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ztmetro";
  version = "0.1.0-alpha2";

  src = lib.cleanSource ../../ztmetro;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    wlroots_0_20
    wayland
    wayland-protocols
    libxkbcommon
    cairo
    pango
    librsvg
    gdk-pixbuf
    pixman
    libdrm
    libGL
    libpulseaudio
    polkit
    systemd
    glib
    zlib
  ];

  postPatch = ''
    substituteInPlace ztmetro-session \
      --replace-fail /usr/local/bin/ztmetro ${placeholder "out"}/bin/ztmetro
  '';

  buildPhase = ''
    runHook preBuild
    make -j"$NIX_BUILD_CORES" all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/sbin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/scalable/apps
    mkdir -p $out/etc/ztstore
    mkdir -p $out/etc/ztoscoresensorframework
    mkdir -p $out/lib/systemd/system

    install -Dm755 auth/ztos-polkit-agent $out/bin/ztos-polkit-agent
    install -Dm755 sounds/ztos-sounds $out/bin/ztos-sounds
    install -Dm755 ztmetro $out/bin/ztmetro
    install -Dm755 ztmetro-session $out/bin/ztmetro-session
    install -Dm755 splash/ztos-splash $out/bin/ztos-splash
    install -Dm755 apps/ztapps $out/bin/ztapps
    install -Dm755 settings/ztsettings $out/bin/ztsettings
    install -Dm755 devtest/zrndevtest $out/bin/zrndevtest
    install -Dm755 devices/ztdevices $out/bin/ztdevices
    install -Dm755 notifyd/ztnotifyd $out/bin/ztnotifyd
    install -Dm755 phone/ztphone $out/bin/ztphone
    install -Dm755 messages/ztmessages $out/bin/ztmessages
    install -Dm755 contacts/ztcontacts $out/bin/ztcontacts

    install -Dm755 perfd/zrnperfd $out/sbin/zrnperfd
    install -Dm755 sensord/ztoscsf-sensord $out/sbin/ztoscsf-sensord
    install -Dm755 modemd/ztoscorenetworkingd $out/sbin/ztoscorenetworkingd
    install -Dm755 csf/ztoscsf $out/sbin/ztoscsf

    install -Dm644 devices/ztdevices.desktop $out/share/applications/ztdevices.desktop
    install -Dm644 devices/ztdevices.svg $out/share/icons/hicolor/scalable/apps/ztdevices.svg
    install -Dm644 comm/ztphone.desktop $out/share/applications/ztphone.desktop
    install -Dm644 comm/ztmessages.desktop $out/share/applications/ztmessages.desktop
    install -Dm644 comm/ztcontacts.desktop $out/share/applications/ztcontacts.desktop
    install -Dm644 comm/ztphone.svg $out/share/icons/hicolor/scalable/apps/ztphone.svg
    install -Dm644 comm/ztmessages.svg $out/share/icons/hicolor/scalable/apps/ztmessages.svg
    install -Dm644 comm/ztcontacts.svg $out/share/icons/hicolor/scalable/apps/ztcontacts.svg

    install -Dm644 store/data/sections $out/etc/ztstore/sections
    install -Dm644 csf/components $out/etc/ztoscoresensorframework/components
    install -Dm644 perfd/zrnperfd.service $out/lib/systemd/system/zrnperfd.service
    install -Dm644 sensord/ztoscsf-sensord.service $out/lib/systemd/system/ztoscsf-sensord.service
    install -Dm644 modemd/ztoscorenetworking-modem.service $out/lib/systemd/system/ztoscorenetworking-modem.service
    install -Dm644 modemd/ztoscorenetworking.service $out/lib/systemd/system/ztoscorenetworking.service
    install -Dm644 csf/ztoscoresensorframework.service $out/lib/systemd/system/ztoscoresensorframework.service

    runHook postInstall
  '';

  meta = {
    description = "ztMETRO, the ztOS shell and its applications";
    homepage = "https://github.com/tellmeY18/ztOS";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "ztmetro";
  };
})
