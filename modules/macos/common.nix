{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkOption mkEnableOption;
  inherit (lib.types) nullOr str int;

  cfg = {
    user = config.rebellion.user;
    homebrew = config.rebellion.homebrew;
  };

  #! https://github.com/LnL7/nix-darwin/issues/852
  #! According to ️^, the using `nix.linux-builder` with `nix*-unstable` doesn't work...
  # linux-builder-package = inputs.nixpkgs-stable.legacyPackages.${system}.darwin.linux-builder;
in
{
  options.rebellion.user = {
    name = mkOption {
      type = str;
      default = "john";
      description = "The user account.";
    };
    email = mkOption {
      type = str;
      default = "jmuchovej@pm.me";
      description = "The user's email.";
    };
    fullName = mkOption {
      type = str;
      default = "John Muchovej";
      description = "The user's full name";
    };
    uid = mkOption {
      type = nullOr int;
      default = 501; # 'cause apple's weird >.>
      description = "The user's account UID.";
    };
  };

  options.rebellion.homebrew = {
    enable = mkEnableOption "homebrew";
    mas = {
      enable = mkEnableOption "Mac App Store downloads";
    };
  };

  config = {
    users.users.${cfg.user.name} = {
      uid = mkIf (cfg.user.uid != null) cfg.user.uid;
      shell = pkgs.zsh;
    };

    homebrew = mkIf cfg.homebrew.enable {
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
    };

    nix = {
      # Options that aren't supported through nix-darwin
      extraOptions = ''
        # bail early on missing cache hits
        connect-timeout = 10
        keep-going = true
      '';

      # gc.user = config.rebellion.user.name;
      # optimise.user = config.rebellion.user.name;
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
