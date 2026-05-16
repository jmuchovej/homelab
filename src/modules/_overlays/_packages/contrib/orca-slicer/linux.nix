{
  lib,
  stdenv,
  binutils,
  boost186,
  copyDesktopItems,
  dbus,
  gcc-unwrapped,
  glew,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  libsecret,
  libx11,
  makeDesktopItem,
  systemd,
  webkitgtk_4_1,
  wrapGAppsHook3,
  withSystemd ? stdenv.hostPlatform.isLinux,
}:
{
  nativeBuildInputs = [
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    binutils
    dbus
    gcc-unwrapped
    glib
    glib-networking
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gtk3
    libsecret
    libx11
    webkitgtk_4_1
  ]
  ++ lib.optionals withSystemd [ systemd ];

  patches = [ ./patches/link-webkit2gtk.patch ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_EXE_LINKER_FLAGS" "-Wl,--no-as-needed")
  ];

  extraCFlags = [
    "-Wno-incompatible-pointer-types"
    "-Wno-template-id-cdtor"
    "-Wno-uninitialized"
    "-Wno-unused-result"
    "-Wno-deprecated-declarations"
    "-Wno-use-after-free"
    "-Wno-format-overflow"
    "-Wno-stringop-overflow"
  ]
  ++ lib.optionals (stdenv.cc.isGNU && lib.versionAtLeast stdenv.cc.version "14") [
    "-Wno-error=template-id-cdtor"
  ];

  extraLDFlags = lib.optionals withSystemd [ "-ludev" ] ++ [
    "-L${boost186}/lib"
    "-lboost_log"
    "-lboost_log_setup"
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "$out/lib:${lib.makeLibraryPath [ glew ]}"
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  postInstall = ''
    rm -f $out/LICENSE.txt
  '';

  separateDebugInfo = true;

  desktopItems = [
    (makeDesktopItem {
      name = "OrcaSlicer";
      desktopName = "OrcaSlicer";
      exec = "orca-slicer %U";
      terminal = false;
      icon = "OrcaSlicer";
      comment = "G-code generator for 3D printers";
      mimeTypes = [ "model/stl" ];
      categories = [
        "Graphics"
        "3DGraphics"
        "Engineering"
      ];
    })
  ];
}
