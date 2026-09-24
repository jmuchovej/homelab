{
  stdenvNoCC,
  unzip,
  pname,
  version,
  src,
  meta,
  passthru,
}:
stdenvNoCC.mkDerivation {
  inherit
    pname
    version
    src
    meta
    passthru
    ;

  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  # The bundle is Developer ID signed and carries a provisioning profile;
  # touching anything inside it (fixup, the asar patches linux.nix applies)
  # breaks the seal and with it push notifications and keychain access.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    mv "Beeper Desktop.app" "$out/Applications/"

    runHook postInstall
  '';
}
