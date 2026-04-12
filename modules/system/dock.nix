# macOS dock layout.
#
# Currently: explicit entries on den.schema.user.dock (name, source, group, order).
# Future: den fx pipeline will enable aspect-driven resolution where programs
# declare dock.app and users set dock.{group,order} on the aspect.
# See memory/dock-class-design.md for implementation plan.
{ den, lib, ... }:
{
  # ── User schema: dock entries ──────────────────────────────────────
  den.schema.user =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) int listOf str submodule;

      dockEntry = submodule {
        options = {
          name = mkOption { type = str; default = ""; };
          path = mkOption { type = str; default = ""; };
          source = mkOption { type = str; default = "applications"; };
          group = mkOption { type = str; };
          order = mkOption { type = int; };
        };
      };
    in
    {
      options.dock = mkOption {
        type = listOf dockEntry;
        default = [ ];
        description = "Dock entries for this user.";
      };
    };

  # ── Darwin aspect: build dock layout ───────────────────────────────
  rbn.system._.dock.darwin =
    {
      host,
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
      hmAppsDir = "/Users/${primaryUser}/Applications/Home Manager Apps";

      allEntries = host.users.${primaryUser}.dock or [ ];

      resolve =
        entry:
        if entry.path != "" then
          entry.path
        else if entry.source == "hm" then
          "${hmAppsDir}/${entry.name}"
        else if entry.source == "system" then
          "/System/Applications/${entry.name}"
        else
          "/Applications/${entry.name}";

      grouped = groupBy (e: e.group) allEntries;
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
