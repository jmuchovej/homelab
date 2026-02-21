{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "home";
  always-active = true;
  options =
    { lib, ... }:
    let
      inherit (lib.types) attrs;
      inherit (lib.rebellion.options) mk;
    in
    {
      file = mk attrs { } "Files managed by home-manager's <option>home.file</option>.";
      config-file = mk attrs { } "Files managed by home-manager's <option>xdg.configFile</option>.";
      extra-options = mk attrs { } "Options to pass directly to home-manager.";
    };
  config =
    {
      cfg,
      config,
      options,
      ...
    }:
    let
      inherit (lib) mkAliasDefinitions;
      username = config.rebellion.user.name;
    in
    {
      rebellion.home.extra-options = {
        home.file = mkAliasDefinitions options.rebellion.home.file;
        xdg.enable = true;
        xdg.configFile = mkAliasDefinitions options.rebellion.home.config-file;
      };

      home-manager.users.${username} = cfg.extra-options;
    };
}
