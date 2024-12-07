{ config, lib, pkgs, outputs, secrets, ... }: {
  options = {
    node = lib.mkOption {
      type = lib.types.submodule ({ name, ...}: {
        options = {
          hostname = lib.mkOption { type = lib.types.str; };
          datacenter = lib.mkOption { type = lib.types.str; };
          domain = lib.mkOption { type = lib.types.str; };
          qualified-name = lib.mkOption {
            type = lib.types.str;
            default = config.node.hostname + "-" + config.node.datacenter;
          };
        };
      });
    };
  };

  imports = [
    ./users/lab.nix
    ./modules/terminal.nix
  ];

  config = {
    nixpkgs = {
      config.allowUnfree = true;
      overlays = [
        outputs.overlays.additions
        outputs.overlays.stable-packages
      ];
    };

    networking = {
      hostName  = config.node.qualified-name;
      domain    = config.node.domain;
    };

    # Basic environment
    environment.systemPackages = [ ];

    i18n.defaultLocale  = "en_US.UTF-8";
    time.timeZone       = "America/New_York";

    users.mutableUsers  = false;

    sops.defaultSopsFormat = "yaml";

    # Nix
    nix = {
      gc = {
        automatic = true;
        dates     = "weekly";
        options   = "--delete-older-than 30d";
      };

      extraOptions                = ''experimental-features = nix-command flakes'';
      settings.trusted-users      = [ "root" "@wheel" ];
      optimise.automatic          = true;
      # generateRegistryFromInputs  = true;
      # generateNixPathFromInputs   = true;
    };

    system.autoUpgrade = {
      enable      = true;
      allowReboot = true;
      dates       = "03:00";
      flake       = "github:jmuchovej/homelab";
    };

    security.sudo = {
      enable              = true;
      execWheelOnly       = true;
      wheelNeedsPassword  = false;
    };

    security.polkit = {
      enable          = true;
      adminIdentities = [ "unix-group:wheel" ];
    };

    programs.zsh = {
      enable                = true;
      enableCompletion      = true;
      enableBashCompletion  = true;
    };

    users.groups."games".gid = 60;
  };
}
