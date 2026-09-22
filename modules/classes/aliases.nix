{
  den,
  lib,
  denTest,
  ...
}:
let
  is-macos = host: host ? class && host.class == "darwin";

  # `hm-<platform>` class name -> the `stdenv.hostPlatform.is<...>` predicate
  # gating it. Keys must be injective: two entries mapping to the same class
  # would forward that class' content once per entry, under different guards.
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

  # NOTE: the forwarded `hm*` classes accept plain config attrsets only.
  # den's `guardTree` wraps a function body as `_modArgs: { config = body; }`,
  # so a module written with `imports`, `options`, or an explicit `config` key
  # gets reinterpreted as option definitions (`config.imports`, `config.config`
  # …). Those modules must stay on the native `homeManager` class — see
  # `secrets/secrets.nix` and `ai-tools/claude.nix`.
  hm-alias =
    { class, aspect-chain }:
    den.batteries.forward {
      each = lib.singleton class;
      fromClass = _: "hm";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
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

  den.policies.hm-to-home-manager =
    _:
    den.lib.policy.route {
      fromClass = "hm";
      intoClass = "homeManager";
      path = [ ];
    };

  # Unit tests, co-located. `denTest` evaluates den in isolation against
  # throwaway hosts, so this asserts the *negative* case (content correctly
  # NOT applied) — which a real-host eval cannot do cheaply. Note the tests
  # reference `hm-platform-alias` from the `let` above rather than importing
  # this file: importing it into the test would recurse into these tests.
  flake.tests.classes.aliases = {
    test-forwards-per-os = denTest (
      { igloo, apple, ... }:
      {
        den.hosts.x86_64-linux.igloo.users.tux = { };
        den.hosts.aarch64-darwin.apple.users.tux = { };

        den.default.includes = [ hm-platform-alias ];

        den.aspects.tux = {
          hm-linux.home.sessionVariables.OS = "linux";
          hm-macos.home.sessionVariables.OS = "macos";
        };

        expr = {
          linux = igloo.home-manager.users.tux.home.sessionVariables.OS or null;
          darwin = apple.home-manager.users.tux.home.sessionVariables.OS or null;
        };

        expected = {
          linux = "linux";
          darwin = "macos";
        };
      }
    );

    # `hm-alias` carries no `guard`/`adaptArgs`, so `forward` direct-imports the
    # source module into the home-manager eval and the module system resolves
    # `pkgs` (and `osConfig`) normally. Adding either would flip it onto the
    # adapter path, which hand-builds the arg set — only args named in
    # `functionArgs guard` survive, and the per-scope adapter defeats den's
    # module dedup, delivering the aspect once per resolving entity. See
    # `hm-platform-alias`, which needs a guard and therefore does double.
    test-hm-receives-pkgs = denTest (
      { igloo, ... }:
      {
        den.hosts.x86_64-linux.igloo.users.tux = { };

        den.default.includes = [ hm-alias ];

        den.aspects.tux.hm =
          { pkgs, ... }:
          {
            home.sessionVariables.HM_PKGS = pkgs.hello.pname;
          };

        expr = igloo.home-manager.users.tux.home.sessionVariables.HM_PKGS or null;
        expected = "hello";
      }
    );

    # Guards the `amd64 -> isx86_64` mapping: `is64bit` is also true on
    # aarch64, which would leak hm-amd64 content onto Apple Silicon.
    test-forwards-per-arch = denTest (
      { igloo, apple, ... }:
      {
        den.hosts.x86_64-linux.igloo.users.tux = { };
        den.hosts.aarch64-darwin.apple.users.tux = { };

        den.default.includes = [ hm-platform-alias ];

        den.aspects.tux = {
          hm-amd64.home.sessionVariables.ARCH = "amd64";
          hm-arm64.home.sessionVariables.ARCH = "arm64";
        };

        expr = {
          linux = igloo.home-manager.users.tux.home.sessionVariables.ARCH or null;
          darwin = apple.home-manager.users.tux.home.sessionVariables.ARCH or null;
        };

        expected = {
          linux = "amd64";
          darwin = "arm64";
        };
      }
    );
  };
}
