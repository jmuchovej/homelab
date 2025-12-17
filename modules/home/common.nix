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
    ;
  inherit (pkgs.stdenv) isDarwin;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion;

  home-directory =
    let
      computed =
        if cfg.user.name == null then
          null
        else if isDarwin then
          /Users + "/${cfg.user.name}"
        else
          /home + "/${cfg.user.name}";
      result = computed;
    in
    result;
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
        description = "Username";
      };
      home = mkOption {
        type = nullOr path;
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

  config = {
    programs.home-manager = enabled;
    home.homeDirectory = mkIf (cfg.user.home != null) (mkDefault cfg.user.home);
    home.preferXdgDirectories = mkDefault true;

    nix = {
      enable = mkDefault cfg.nix.enable;
      settings = {
        use-xdg-base-directories = true;
        warn-dirty = false;
      };
    };

    rebellion = {
      modern-unix = enabled;
      ssh = enabled;
      git = enabled;

      shell.zsh = enabled;
      editor.neovim = enabled // {
        default = mkDefault true;
      };
    };
  };
}
