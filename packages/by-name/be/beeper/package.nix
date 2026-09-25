{
  lib,
  stdenv,
  callPackage,
  fetchurl,
  writeShellApplication,
  curl,
  common-updater-scripts,
}:
let
  pname = "beeper";
  version = "4.3.144";

  inherit (stdenv.hostPlatform) system;

  base = "https://beeper-desktop.download.beeper.com/builds/Beeper-${version}";

  sources = {
    x86_64-linux = fetchurl {
      url = "${base}-x86_64.AppImage";
      hash = "sha512-mQnCu+bMG0HeebmFPfzovzQqSgTA0wLJ+/obJXI/k5Eu0BkXeuJb+Ay2xBH8O5Z2hi7Y9Ilku0W4SGhVGpfDFw==";
    };
    aarch64-linux = fetchurl {
      url = "${base}-arm64.AppImage";
      hash = "sha512-LYQRZH5Sntcr/Q1p1EK4Ae4viGHXTUnv2harXMFB2O62s5h5PF0ql25MK/QkXhM1MO4n38/d65pDQi7nKnPlRg==";
    };
    x86_64-darwin = fetchurl {
      url = "${base}-mac.zip";
      hash = "sha512-yEt6DuBiFbEg1oaJ/pnJuLon1/xcQ5QO1Wu2vY2P8SPvJZVO1X29KyYlBqSGSpZp1B17V7gO9PsM4hgQYQC5fA==";
    };
    aarch64-darwin = fetchurl {
      url = "${base}-arm64-mac.zip";
      hash = "sha512-xjrjpVmEA2ydOzb3ut7R9kBBLJ94HNjYTRwPV/472wC68Ve3N7hiKndN+A+X1xt23dmL5/LVlE8N/YuKPxCLHQ==";
    };
  };

  src = sources.${system} or (throw "beeper is not supported on ${system}");

  passthru = {
    inherit sources;
    updateScript = lib.getExe (writeShellApplication {
      name = "update-beeper";
      runtimeInputs = [
        curl
        common-updater-scripts
      ];
      text = ''
        set -o errexit
        latestLinux="$(curl --silent --output /dev/null --write-out "%{redirect_url}\n" https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop)"
        version="$(echo "$latestLinux" | grep --only-matching --extended-regexp '[0-9]+\.[0-9]+\.[0-9]+')"
        for platform in ${lib.escapeShellArgs (lib.attrNames sources)}; do
          update-source-version beeper "$version" --ignore-same-version --source-key="passthru.sources.$platform"
        done
      '';
    });
  };

  meta = {
    description = "Universal chat app";
    longDescription = ''
      Beeper is a universal chat app. With Beeper, you can send
      and receive messages to friends, family and colleagues on
      many different chat networks.
    '';
    homepage = "https://beeper.com";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      jshcmpbll
      zh4ngx
      aspauldingcode
    ];
    platforms = lib.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "beeper";
  };

  variant = if stdenv.hostPlatform.isDarwin then ./darwin.nix else ./linux.nix;
in
callPackage variant {
  inherit
    pname
    version
    src
    meta
    passthru
    ;
}
