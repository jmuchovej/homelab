{
  lib,
  runCommand,
  appimageTools,
  makeWrapper,
  asar,
  pname,
  version,
  src,
  meta,
  passthru,
}:
let
  # Beeper 4.2.985+ ships AppImages without the type-2 magic bytes
  # (ASCII "AI" + 0x02 at ELF offset 8) that appimageTools.extract requires.
  linuxSrc = runCommand "Beeper-${version}-appimage" { inherit src; } ''
    cp $src $out
    chmod +w $out
    printf 'AI\x02' | dd of=$out bs=1 seek=8 conv=notrunc status=none
  '';

  appimageContents = appimageTools.extract {
    inherit pname version;
    src = linuxSrc;

    postExtract = ''
      appRoot="$out/resources/app"
      ${lib.getExe asar} extract "$out/resources/app.asar" "$appRoot"
      rm "$out/resources/app.asar"

      # disable creating a desktop file and icon in the home folder during runtime
      linuxConfigFilename=$appRoot/build/main/linux-*.mjs
      echo "export function registerLinuxConfig() {}" > $linuxConfigFilename

      # Disable scheduled update checks.
      autoUpdateConfigFilename=$(
        grep -lF 'c=d??{},p=c.hw_acceleration??!0' $appRoot/build/main/index-*.mjs
      )
      substituteInPlace "$autoUpdateConfigFilename" \
        --replace-fail 'c=d??{},p=c.hw_acceleration??!0' 'c={...(d??{}),auto_update_disabled:true},p=c.hw_acceleration??!0'

      # Disable user-triggered update checks, which ignore auto_update_disabled.
      # The minifier renames the parameter between releases (r=!1, t=!1, …),
      # so match it by shape and then assert the edit landed.
      sed -i -E 's/async checkForUpdates\(([a-z])=!1\)\{/async checkForUpdates(\1=!1){return;/' \
        $appRoot/build/main/main-entry-*.mjs
      grep -qE 'async checkForUpdates\([a-z]=!1\)\{return;' $appRoot/build/main/main-entry-*.mjs
    '';
  };
in
appimageTools.wrapAppImage {
  inherit
    pname
    version
    meta
    passthru
    ;

  src = appimageContents;

  extraPkgs = pkgs: [ pkgs.libsecret ];

  extraInstallCommands = ''
    install -Dm 644 ${appimageContents}/beepertexts.png $out/share/icons/hicolor/512x512/apps/beepertexts.png
    install -Dm 644 ${appimageContents}/beepertexts.desktop -t $out/share/applications/
    substituteInPlace $out/share/applications/beepertexts.desktop --replace-fail "AppRun" "beeper"

    . ${makeWrapper}/nix-support/setup-hook
    wrapProgram $out/bin/beeper \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set APPIMAGE beeper \
      --run 'exec >/dev/null' # as recommended in #486164
  '';
}
