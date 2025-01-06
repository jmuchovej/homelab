{
  pkgs,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkForce;
  inherit (lib.${namespace}) enabled;
in
{
  networking.wireless.enable = mkForce false;

  environment.systemPackages = with pkgs;
    [
      git
      wget
      curl
      pciutils
      file
    ];

  boot.loader.systemd-boot = enabled;

  ${namespace} = {
    nix = enabled;

    programs.editors.neovim = enabled;
    programs.tools = {
      tmux = enabled;
      starship = enabled;
      bat = enabled;
      eza = enabled;
    };
    programs.shells = {
      zsh = enabled;
    };

    services.openssh = enabled;
    security.doas = enabled;

    system.boot = enabled;
    system.fonts = enabled;
    system.locale = enabled;
    system.time = enabled;
    system.networking = enabled;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO lab@home.jm0.io"
  ];

  system.stateVersion = "24.11";
}
