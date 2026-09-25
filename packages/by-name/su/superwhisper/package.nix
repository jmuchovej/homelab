{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "superwhisper";
  version = "2.18.4";

  src = fetchurl {
    url = "https://builds.superwhisper.com/v${finalAttrs.version}/superwhisper.zip";
    hash = "sha256-l9iSYrz3FgPLuJ2yfLzTVh05imiE+/pIr6SNtYpp82A=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  # The bundle is Developer ID signed; any rewrite of the Mach-O breaks the
  # signature and Gatekeeper refuses to launch it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    mv superwhisper.app $out/Applications

    runHook postInstall
  '';

  meta = {
    description = "Dictation tool including LLM reformatting";
    homepage = "https://superwhisper.com";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
