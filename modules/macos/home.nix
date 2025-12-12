{
  config,
  lib,
  options,
  namespace,
  ...
}:
let
  inherit (lib) mkAliasDefinitions mkOption;
  inherit (lib.types) attrs;
  inherit (lib.rebellion) mkOpt;

  username = config.rebellion.user.name;
  ns-home = options.rebellion.home;
in
{
  options.rebellion.home = {
    file = mkOption {
      type = attrs;
      default = { };
      description = "A set of files to be managed by home-manager's <option>home.file</option>.";
    };
    configFile = mkOption {
      type = attrs;
      default = { };
      description = "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
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

  config = {
    rebellion.home.extraOptions = {
      home.file = mkAliasDefinitions options.rebellion.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.rebellion.home.configFile;
    };

    users.users.${username}.home = /. + "/Users/${username}";

    # snowfallorg.users.${username}.home.config =
    #   mkAliasDefinitions options.rebellion.home.extraOptions;

    home-manager = {
      backupFileExtension = "hm.bak";

      useUserPackages = true;
      useGlobalPkgs = true;

      verbose = true;
    };
  };
}
