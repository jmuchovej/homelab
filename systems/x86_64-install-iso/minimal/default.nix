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

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    pciutils
    file
  ];

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

  system.stateVersion = "24.11";
}
