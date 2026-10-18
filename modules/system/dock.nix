{
  den,
  denTest,
  lib,
  ...
}:
let
  sources = [
    "hm"
    "brew"
    "user-apps"
    "root-apps"
    "nix-apps"
    "system-apps"
  ];

  # Shared with the unit test below rather than imported there: importing this
  # file into the test would recurse into the test itself.
  schema =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      app =
        with lib.types;
        coercedTo str (key: { inherit key; }) (submodule {
          options = {
            key = mkOption { type = str; };
            source = mkOption {
              type = nullOr (enum sources);
              default = null;
            };
            path = mkOption {
              type = nullOr str;
              default = null;
            };
          };
        });
      group =
        with lib.types;
        submodule {
          options = {
            order = mkOption { type = int; };
            apps = mkOption {
              type = listOf app;
              default = [ ];
            };
          };
        };
    in
    {
      options.dock = mkOption {
        type = lib.types.attrsOf group;
        default = { };
        description = "Dock layout: named groups of app keys, rendered in `order`.";
      };
    };

  aspect.macos =
    {
      config,
      user,
      lib,
      ...
    }:
    let
      inherit (lib)
        tail
        foldl
        pipe
        attrValues
        filter
        listToAttrs
        nameValuePair
        sort
        ;

      home = "/Users/${user.userName}";
      app-dir = {
        hm = "${home}/Applications/Home Manager Apps";
        brew = config.homebrew.caskArgs.appdir;
        user-apps = "${home}/Applications";
        root-apps = "/Applications";
        nix-apps = "/Applications/Nix Apps";
        system-apps = "/System/Applications";
      };

      macos-builtins = {
        "System Settings".source = "system-apps";
        "Messages".source = "system-apps";
        "Safari".source = "root-apps";
        "Activity Monitor".path = "${app-dir.system-apps}/Utilities/Activity Monitor.app";
      };
      declared = pipe user.aspects [
        (filter (n: n ? dock))
        (map (n: nameValuePair n.dock.key n.dock))
        listToAttrs
      ];
      registry = macos-builtins // declared;

      path-of =
        entry:
        let
          known = registry.${entry.key} or null;
          source = if entry.source != null then entry.source else known.source or null;
          path = if entry.path != null then entry.path else known.path or null;
        in
        if path != null then
          path
        else if source != null then
          "${
            app-dir.${source} or (throw "dock: `${entry.key}` declares unknown source `${source}`")
          }/${entry.key}.app"
        else
          throw "dock: nothing in ${user.name}'s tree declares `dock.key = \"${entry.key}\"`; give the entry a `source` or `path`";

      spacer = [
        { spacer.small = true; }
      ];
      layout = pipe user.dock [
        # build groups
        attrValues
        (filter (g: g.apps != [ ]))
        (sort (a: b: a.order < b.order))
        # flatten into a with an interspersed `spacer`
        (map (g: map (e: { app = path-of e; }) g.apps))
        (foldl (acc: apps: acc ++ spacer ++ apps) [ ])
        tail
      ];
    in
    {
      system.defaults.dock.persistent-apps = layout;
    };
in
{
  den.reservedKeys = [ "dock" ];
  den.schema.user = schema;
  rbn.system._.dock = aspect;

  flake.tests.system.dock = {
    test-layout-from-aspect-metadata = denTest (
      { apple, den, ... }:
      {
        den.reservedKeys = [ "dock" ];
        den.schema.user = schema;

        den.policies.macos-to-darwin =
          { host, ... }:
          lib.optional (host.class == "darwin") (
            den.lib.policy.route {
              fromClass = "macos";
              intoClass = host.class;
              path = [ ];
            }
          );
        den.default.includes = [ den.policies.macos-to-darwin ];

        den.hosts.aarch64-darwin.apple.users.tux.dock = {
          editors = {
            order = 200;
            apps = [ "Zed" ];
          };
          system = {
            order = 100;
            apps = [
              "System Settings"
              "Activity Monitor"
              {
                key = "Delta";
                source = "root-apps";
              }
            ];
          };
          empty.order = 50;
        };

        den.aspects.tux.includes = [
          aspect
          {
            name = "zed";
            dock = {
              key = "Zed";
              source = "hm";
            };
          }
        ];

        expr = apple.system.defaults.dock.persistent-apps;
        # nix-darwin renders `{ app }` / `{ spacer }` into dock tiles.
        expected =
          let
            app = path: {
              tile-data.file-data = {
                _CFURLString = path;
                _CFURLStringType = 0;
              };
            };
            spacer = {
              tile-data = { };
              tile-type = "small-spacer-tile";
            };
          in
          [
            (app "/System/Applications/System Settings.app")
            (app "/System/Applications/Utilities/Activity Monitor.app")
            (app "/Applications/Delta.app")
            spacer
            (app "/Users/tux/Applications/Home Manager Apps/Zed.app")
          ];
      }
    );
  };
}
