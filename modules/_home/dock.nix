{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "dock";
  always-active = true;
  options =
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
            description = "Absolute path to the .app bundle. Mutually exclusive with `name`.";
          };
          name = mkOption {
            type = nullOr str;
            default = null;
            description = "App bundle name (e.g. \"Foo.app\"), resolved via `source`. Mutually exclusive with `path`.";
          };
          source = mkOption {
            type = enum [
              "hm"
              "system"
              "applications"
            ];
            default = "hm";
            description = ''
              Path prefix for `name` resolution:
              - "hm" → ~/Applications/Home Manager Apps/
              - "system" → /System/Applications/
              - "applications" → /Applications/
            '';
          };
          group = mkOption {
            type = str;
            description = "Grouping key. Spacers are auto-inserted between groups.";
          };
          order = mkOption {
            type = int;
            description = "Sort order within and across groups.";
          };
        };
      };
    in
    {
      entries = mkOption {
        type = listOf entryType;
        default = [ ];
        description = "Dock entries collected from all modules.";
      };
    };
}
