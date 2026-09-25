{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "no-tunes";
  version = "3.5";

  src = fetchurl {
    url = "https://github.com/tombonez/noTunes/releases/download/v${finalAttrs.version}/noTunes-${finalAttrs.version}.zip";
    hash = "sha256-B4Nc+fO/MU0R8uvlKAcqIA/6LVXzjeWQhZecLUduo9U=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  # The bundle is Developer ID signed; any rewrite of the Mach-O breaks the
  # signature and Gatekeeper refuses to launch it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    mv noTunes.app $out/Applications

    runHook postInstall
  '';

  meta = {
    description = "Prevent iTunes or Apple Music from launching";
    homepage = "https://github.com/tombonez/noTunes";
    changelog = "https://github.com/tombonez/noTunes/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
