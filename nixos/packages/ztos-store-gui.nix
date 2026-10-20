{
  lib,
  stdenv,
  wrapGAppsHook4,
  gobject-introspection,
  gtk4,
  libadwaita,
  graphene,
  python3,
  gdk-pixbuf,
  librsvg,
}:

let
  python = python3.withPackages (ps: [ ps.pygobject3 ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ztos-store-gui";
  version = "0.1.0-alpha2";

  src = ../../ztmetro/store-gui;

  nativeBuildInputs = [
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    gtk4
    libadwaita
    graphene
    python
    gdk-pixbuf
    librsvg
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 ztos-store-gui.py $out/libexec/ztos-store-gui.py
    install -Dm644 ztos-store.desktop $out/share/applications/ztos-store.desktop
    install -Dm644 ztos-store.svg $out/share/icons/hicolor/scalable/apps/ztos-store.svg

    mkdir -p $out/bin
    cat > $out/bin/ztos-store-gui <<EOF
    #!${stdenv.shell}
    exec ${python}/bin/python3 $out/libexec/ztos-store-gui.py "\$@"
    EOF
    chmod 0755 $out/bin/ztos-store-gui

    runHook postInstall
  '';

  meta = {
    description = "The ztOS Store app";
    homepage = "https://github.com/Zerone-Laboratories/ztOS";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "ztos-store-gui";
  };
})
