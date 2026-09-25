{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  build = "4850";
in
stdenvNoCC.mkDerivation {
  pname = "affinity";
  version = "3.3.0";

  src = fetchurl {
    url = "https://affinity-update.s3.amazonaws.com/mac2/retail/Affinity%20Affinity%20Store%20${build}.zip";
    hash = "sha256-MX9c9kpTZDGYmFdrRki2qW3J7Dn1ADmuv5kBt+06XZY=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  # The bundle is Developer ID signed and notarized; any rewrite of the
  # Mach-O breaks the signature and Gatekeeper refuses to launch it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    mv Affinity.app $out/Applications

    runHook postInstall
  '';

  meta = {
    description = "Image editing and design software";
    homepage = "https://www.affinity.studio/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
