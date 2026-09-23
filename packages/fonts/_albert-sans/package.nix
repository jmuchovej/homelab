# TODO look into what's required to package with Nerd Fonts / FontForge
# https://github.com/usted/Albert-Sans/
{ stdenv, ... }:
stdenv.mkDerivation {
  pname = "albert-sans";
  version = "0.1.0";

  src = ./_files;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts
    cp -R $src $out/share/fonts/truetype/

    runHook postInstall
  '';
}
