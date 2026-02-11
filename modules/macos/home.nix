{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "home";
  always-active = true;
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) attrs;
    in
    {
      file = mkOption {
        type = attrs;
        default = { };
        description = "A set of files to be managed by home-manager's home.file.";
      };
      configFile = mkOption {
        type = attrs;
        default = { };
        description = "A set of files to be managed by home-manager's xdg.configFile.";
      };
      extraOptions = mkOption {
        type = attrs;
        default = { };
        description = "Options to pass directly to home-manager.";
      };
      homeConfig = mkOption {
        type = attrs;
        default = { };
        description = "Final config for home-manager.";
      };
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
      rebellion.home.extraOptions = {
        home.file = mkAliasDefinitions options.rebellion.home.file;
        xdg.enable = true;
        xdg.configFile = mkAliasDefinitions options.rebellion.home.configFile;
      };

      users.users.${username}.home = /. + "/Users/${username}";

      home-manager.users.${username} = cfg.extraOptions;

      home-manager = {
        backupFileExtension = "hm.bak";

        useUserPackages = true;
        useGlobalPkgs = true;

        verbose = true;
      };
    };
}
