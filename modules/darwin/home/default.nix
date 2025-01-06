{
  config,
  lib,
  options,
  namespace,
  ...
}: let
  inherit (lib) mkAliasDefinitions mkOption;
  inherit (lib.types) attrs;
  inherit (lib.${namespace}) mkOpt;

  username = config.${namespace}.user.name;
  ns-home = options.${namespace}.home;
in {
  options.${namespace}.home = {
    file = mkOption {
      type = attrs;
      default = {};
      description = "A set of files to be managed by home-manager's <option>home.file</option>.";
    };
    configFile = mkOption {
      type = attrs;
      default = {};
      description = "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
    };
    extraOptions = mkOption {
      type = attrs;
      default = {};
      description = "Options to pass directly to home-manager.";
    };
    homeConfig = mkOption {
      type = attrs;
      default = {};
      description = "Final config for home-manager.";
    };
  };

  config = {
    ${namespace}.home.extraOptions = {
      home.file = mkAliasDefinitions options.${namespace}.home.file;
      xdg.enable = true;
      xdg.configFile = mkAliasDefinitions options.${namespace}.home.configFile;
    };

    snowfallorg.users.${username}.home.config =
      mkAliasDefinitions options.${namespace}.home.extraOptions;

    home-manager = {
      backupFileExtension = "hm.bak";

      useUserPackages = true;
      useGlobalPkgs = true;

      verbose = true;
    };
  };
}
