# TODO look into what's required to package with Nerd Fonts / FontForge
{
  stdenv,
  ...
}:
stdenv.mkDerivation rec {
  pname = "brandon-text";
  version = "0.1.0";

  src = ./brandon-text;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts
    cp -R $src $out/share/fonts/truetype/

    runHook postInstall
  '';
}
