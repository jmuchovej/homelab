{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system.dock";
  always-active = true;
  config =
    { config, lib, ... }:
    let
      inherit (lib)
        attrNames
        concatMap
        foldl'
        groupBy
        min
        optional
        sort
        ;

      username = config.rebellion.user.name;
      hmDockEntries = config.home-manager.users.${username}.rebellion.dock.entries;
      home-manager-apps = "/Users/${username}/Applications/Home Manager Apps";

      resolve =
        entry:
        if entry.path != null then
          entry.path
        else if entry.source == "hm" then
          "${home-manager-apps}/${entry.name}"
        else if entry.source == "system" then
          "/System/Applications/${entry.name}"
        else
          "/Applications/${entry.name}";

      grouped = groupBy (e: e.group) hmDockEntries;

      minOrder = name: foldl' min 9999 (map (e: e.order) grouped.${name});

      sortedGroupNames = sort (a: b: minOrder a < minOrder b) (attrNames grouped);

      buildDock =
        let
          indexed = lib.imap0 (
            i: groupName:
            let
              spacer = optional (i > 0) { spacer.small = true; };
              entries = sort (a: b: a.order < b.order) grouped.${groupName};
              resolved = map (e: { app = resolve e; }) entries;
            in
            spacer ++ resolved
          ) sortedGroupNames;
        in
        concatMap (x: x) indexed;
    in
    {
      system.defaults.dock.persistent-apps = buildDock;
    };
}
