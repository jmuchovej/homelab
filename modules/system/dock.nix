# macOS dock layout via custom den class.
#
# Program aspects declare dock entries as a `dock` class key:
#   rbn.programs._.media._.spotify.dock = {
#     name = "Spotify.app"; source = "applications"; group = "comm"; order = 230;
#   };
#
# The `dock` class forwards into homeManager's `rebellion.dock.entries`.
# The darwin aspect reads entries and builds `system.defaults.dock.persistent-apps`.
{ den, lib, ... }:
let
  # Forward `dock` class → homeManager `rebellion.dock.entries`
  dockClass =
    { class, aspect-chain, ... }:
    den._.forward {
      each = lib.singleton true;
      fromClass = _: "dock";
      intoClass = _: "homeManager";
      intoPath = _: [
        "rebellion"
        "dock"
        "entries"
      ];
      fromAspect = _: lib.head aspect-chain;
    };
in
{
  # Register the dock class in the user context pipeline
  den.ctx.user.includes = [ dockClass ];

  # Define the HM-level collection option
  den.default.homeManager =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types)
        enum
        int
        listOf
        nullOr
        str
        submodule
        ;

      entryType = submodule {
        options = {
          path = mkOption {
            type = nullOr str;
            default = null;
            description = "Absolute path to the .app bundle.";
          };
          name = mkOption {
            type = nullOr str;
            default = null;
            description = "App bundle name (e.g. \"Foo.app\").";
          };
          source = mkOption {
            type = enum [
              "hm"
              "system"
              "applications"
            ];
            default = "hm";
            description = "Path prefix for name resolution.";
          };
          group = mkOption {
            type = str;
            description = "Grouping key.";
          };
          order = mkOption {
            type = int;
            description = "Sort order within and across groups.";
          };
        };
      };
    in
    {
      options.rebellion.dock.entries = mkOption {
        type = listOf entryType;
        default = [ ];
        description = "Dock entries collected from all aspects.";
      };
    };

  # Darwin aspect: read entries and build dock layout
  rbn.system._.dock.darwin =
    {
      host,
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        attrNames
        concatMap
        foldl'
        groupBy
        imap0
        min
        optional
        sort
        ;

      primaryUser = host.user.name;
      hmUsers = config.home-manager.users;

      dockEntries = hmUsers.${primaryUser}.rebellion.dock.entries or [ ];
      hmAppsDir = "/Users/${primaryUser}/Applications/Home Manager Apps";

      resolve =
        entry:
        if entry.path != null then
          entry.path
        else if entry.source == "hm" then
          "${hmAppsDir}/${entry.name}"
        else if entry.source == "system" then
          "/System/Applications/${entry.name}"
        else
          "/Applications/${entry.name}";

      grouped = groupBy (e: e.group) dockEntries;
      minOrder = name: foldl' min 9999 (map (e: e.order) grouped.${name});
      sortedGroupNames = sort (a: b: minOrder a < minOrder b) (attrNames grouped);

      buildDock = concatMap (x: x) (
        imap0 (
          i: groupName:
          let
            spacer = optional (i > 0) { spacer.small = true; };
            entries = sort (a: b: a.order < b.order) grouped.${groupName};
            resolved = map (e: { app = resolve e; }) entries;
          in
          spacer ++ resolved
        ) sortedGroupNames
      );
    in
    {
      system.defaults.dock.persistent-apps = buildDock;
    };
}
