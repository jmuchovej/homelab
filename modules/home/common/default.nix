{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    mkDefault
    mkIf
    mkEnableOption
    mkMerge
    ;
  inherit (pkgs.stdenv) isDarwin;
  inherit (lib.rebellion) mkopt enabled;

  cfg = config.rebellion;

  home-directory =
    if cfg.user.name == null then
      null
    else if isDarwin then
      "/Users/${cfg.user.name}"
    else
      "/home/${cfg.user.name}";
in
{
  options.rebellion = with types; {
    # host = {
    #   name = mkOption {
    #     type = nullOr str;
    #     default = host;
    #     description = "The hostname.";
    #   };
    # };

    user = {
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
      real-name = mkOption {
        type = nullOr str;
        description = "Your real name.";
      };
    };

    nix = {
      enable = mkEnableOption "configuring nix";
    };
  };

  config = (
    mkMerge [
      {
        assertions = [
          {
            assertion = cfg.user.name != null;
            message = "rebellion.user.name must be set!";
          }
          {
            assertion = cfg.user.home != null;
            message = "rebellion.home.name must be set!";
          }
        ];

        programs.home-manager = enabled;
        home.username = mkDefault cfg.user.name;
        home.homeDirectory = mkDefault cfg.user.home;
        home.preferXdgDirectories = mkDefault true;
      }
      {
        nix = {
          enable = mkDefault cfg.nix.enable;
          settings = {
            use-xdg-base-directories = true;
            warn-dirty = false;
          };
        };

        rebellion = {
          shell.zsh = enabled;
          editor.neovim = enabled // {
            default = true;
          };
        };
      }
    ]
  );
}
