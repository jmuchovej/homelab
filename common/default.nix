{ config, lib, pkgs, outputs, ... }: {
  imports = [
    ./users/lab.nix
    ./modules/terminal.nix
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      outputs.overlays.additions
      outputs.overlays.stable-packages
    ];
  };

  # Basic environment
  environment.systemPackages = [ ];

  i18n.defaultLocale  = "en_US.UTF-8";
  time.timeZone       = "America/New_York";

  users.mutableUsers  = false;

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
    enableCompletions     = true;
    enableBashCompletions = true;
  };
}
