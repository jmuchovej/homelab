{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = null;
  options =
    let
      inherit (lib.types) str nullOr int;
      inherit (lib.rebellion) mkopt mkopt-enable;
    in
    {
      user = {
        name = mkopt str "john" "The user's account";
        email = mkopt str "john@jm0.io" "The user's email";
        full-name = mkopt str "John Muchovej" "The user's full name.";
        uid = mkopt (nullOr int) 501 "The user's account UID";
      };
      homebrew = {
        enable = mkopt-enable "homebrew";
        mas.enable = mkopt-enable "Mac App Store downloads";
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
