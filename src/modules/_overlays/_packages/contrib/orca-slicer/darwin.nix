{
  lib,
  darwinMinVersionHook,
}:
{
  buildInputs = [
    # OrcaSlicer upstream sets CMAKE_OSX_DEPLOYMENT_TARGET=11.3
    (darwinMinVersionHook "11.3")
    # All required frameworks (IOKit, CoreFoundation, AVFoundation, AVKit,
    # CoreMedia, VideoToolbox, Security, DiskArbitration, OpenGL) are provided
    # by the default apple-sdk (14.4) already in stdenv.
  ];

  # On macOS, the upstream code uses an #ifdef __APPLE__ block that resolves
  # resources relative to the app bundle (../../Resources). Since we build with
  # SLIC3R_FHS=1, we need the SLIC3R_FHS code path instead.
  # This is the same fix PrusaSlicer uses in nixpkgs.
  prePatch = ''
    substituteInPlace src/OrcaSlicer.cpp \
      --replace-fail "#ifdef __APPLE__" "#if 0"
  '';

  extraCFlags = [
    "-Wno-deprecated-declarations"
  ];

  postInstall = ''
    rm -f $out/LICENSE.txt
  '';

  separateDebugInfo = false;
}
