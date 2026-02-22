{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = null;
  options =
    { cfg, pkgs, ... }:
    with lib.types;
    let
      inherit (pkgs.stdenv) isDarwin;
      inherit (lib.rebellion) options;

      home-directory =
        if cfg.user.name == null then
          null
        else if isDarwin then
          /Users + "/${cfg.user.name}"
        else
          /home + "/${cfg.user.name}";
    in
    {
      # host = {
      #   name = options.mk (nullOr str) host "The hostname";
      # };

      user = {
        name = options.mk (nullOr str) null "Username";
        home = options.mk (nullOr path) home-directory "Home directory";
        real-name = options.mk (nullOr str) null "Your real name";
      };

      nix = {
        enable = options.mk-bool' false;
      };
    };
  config =
    { cfg, ... }:
    let
      inherit (lib) mkDefault mkIf;
      inherit (lib.rebellion) enabled;
    in
    {
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
          default = mkDefault enabled;
        };
      };
    };
}
