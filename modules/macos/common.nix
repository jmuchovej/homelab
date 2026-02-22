{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = null;
  options =
    let
      inherit (lib.types) str nullOr int;
      inherit (lib.rebellion.options) mk mk-enable';
    in
    {
      user = {
        name = mk str "john" "The user's account";
        email = mk str "john@jm0.io" "The user's email";
        full-name = mk str "John Muchovej" "The user's full name.";
        uid = mk (nullOr int) 501 "The user's account UID";
      };
      homebrew = (mk-enable' "homebrew") // {
        mas = mk-enable' "Mac App Store downloads";
      };
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      users.users.${cfg.user.name} = {
        uid = lib.mkIf (cfg.user.uid != null) cfg.user.uid;
        shell = pkgs.zsh;
      };

      homebrew = lib.mkIf cfg.homebrew.enable {
        enable = true;

        global = {
          brewfile = true;
          autoUpdate = true;
        };

        onActivation = {
          autoUpdate = true;
          cleanup = "uninstall";
          upgrade = true;
        };

        brews = [ ];
      };

      nix-homebrew = lib.mkIf cfg.homebrew.enable {
        enable = true;
        user = cfg.user.name;

        taps = {
          "homebrew/core" = inputs.homebrew-core;
          "homebrew/cask" = inputs.homebrew-cask;
          "homebrew/bundle" = inputs.homebrew-bundle;
          "homebrew/services" = inputs.homebrew-services;
        };
      };

      # home.extraOptions = {
      #   home.shellAliases = {
      #     # Prevent shell log command from overriding macOS log
      #     log = ''command log'';
      #   };
      # };

      environment.systemPackages = with pkgs; [
        gawk
        gnugrep
        gnupg
        gnused
        gnutls
        terminal-notifier
        trash-cli
      ];
    };
}
