{
  den,
  lib,
  ...
}:
let
  is-macos = host: host ? class && host.class == "darwin";

  platform-map = {
    macos = "Darwin";
    linux = "Linux";
    arm64 = "Aarch64";
    amd64 = "x86_64";
  };

  hm-platform-alias =
    { aspect-chain, ... }:
    den.batteries.forward {
      each = lib.attrNames platform-map;
      fromClass = platform: "hm-${platform}";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
      guard = { pkgs, ... }: platform: lib.mkIf pkgs.stdenv.hostPlatform."is${platform-map.${platform}}";
      adaptArgs = { config, ... }: { osConfig = config; };
    };

  hm-alias =
    { class, aspect-chain }:
    den.batteries.forward {
      each = lib.singleton class;
      fromClass = _: "hm";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
      guard = { pkgs, ... }: true;
      adaptArgs = { config, ... }: { osConfig = config; };
    };
in
{
  den.default.includes = [
    hm-platform-alias
    hm-alias
    den.policies.macos-to-darwin
  ];

  den.policies.macos-to-darwin =
    { host, ... }:
    lib.optional (is-macos host) (
      den.lib.policy.route {
        fromClass = "macos";
        intoClass = host.class;
        path = [ ];
      }
    );
}
