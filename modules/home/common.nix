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
  	let
    	name = builtins.trace "DEBUG[common.nix]: cfg.user.name=${toString cfg.user.name}" cfg.user.name;
    	isMacOS = builtins.trace "DEBUG[common.nix]: isDarwin=${toString isDarwin}" isDarwin;
    	computed = if name == null then
      	null
    	else if isMacOS then
      	/Users + "/${cfg.user.name}"
    	else
      	/home + "/${cfg.user.name}";
    	result = builtins.trace "DEBUG[common.nix]: home-directory=${toString computed}" computed;
    in
    	result;
    # home-directory = "/Users/john";
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
      shell.zsh = enabled;
      editor.neovim = enabled // {
        default = true;
      };
    };
  };
}
