{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption mkOption mkMerge;
  inherit (lib.types) nullOr str;
  inherit (lib.${namespace}) enabled;
  inherit (pkgs.stdenv) isDarwin;

  cfg = config.${namespace}.user;

  home-directory =
    if cfg.name == null
    then null
    else if isDarwin
    then "/Users/${cfg.name}"
    else "/home/${cfg.name}";
in {
  options.${namespace}.user = {
    enable = mkEnableOption "Configure a user account?";
    name = mkOption {
      type = nullOr str;
      default = config.snowfallorg.user.name;
      description = "Username";
    };
    home = mkOption {
      type = nullOr str;
      default = home-directory;
      description = "Home Directory";
    };
    fullName = mkOption {
      type = str;
      default = "John Muchovej";
      description = "Your full name.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "${namespace}.user must be set!";
        }
        {
          assertion = cfg.home != null;
          message = "${namespace}.home must be set!";
        }
      ];

      programs.home-manager = enabled;
      home.username = mkDefault cfg.name;
      home.homeDirectory = mkDefault cfg.home;
    }
  ]);
}
