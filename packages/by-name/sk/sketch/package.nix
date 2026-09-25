{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  build = "234013";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sketch";
  version = "2026.3.1";

  src = fetchurl {
    url = "https://download.sketch.com/sketch-${finalAttrs.version}-${build}.zip";
    hash = "sha256-A6u/1rNZTtaSm1PF4pau1ZVD84ZPv72nyc9cQ0c1h8w=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  # The bundle is Developer ID signed and notarized; any rewrite of the
  # Mach-O breaks the signature and Gatekeeper refuses to launch it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    mv Sketch.app $out/Applications

    runHook postInstall
  '';

  meta = {
    description = "Digital design and prototyping platform";
    homepage = "https://www.sketch.com/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
